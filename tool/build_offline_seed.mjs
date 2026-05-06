#!/usr/bin/env node

import fs from 'node:fs';
import crypto from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptPath = fileURLToPath(import.meta.url);
const appRoot = path.resolve(path.dirname(scriptPath), '..');
const webRoot = path.resolve(process.argv[2] ?? path.join(appRoot, '..', 'granite-climbing.github.io'));
const contentRoot = path.join(webRoot, 'content');
const publicImagesRoot = path.join(webRoot, 'public', 'images');
const outputWebRoot = path.join(appRoot, 'assets', 'offline_web');
const outputWebImagesRoot = path.join(outputWebRoot, 'images');
const outputWebPath = path.join(outputWebRoot, 'index.html');
const generatedAt = new Date().toISOString();

const defaultSafetyNote =
  '웹 콘텐츠에는 별도 안전/주의사항 필드가 없어 현장의 출입 통제, 낙석, 착지 상태를 직접 확인하세요.';
const routeSafetyNote =
  '저장된 코스 정보입니다. 실제 홀드 파손, 낙석, 착지 상태를 현장에서 다시 확인하세요.';

main();

function main() {
  assertDirectory(contentRoot);
  assertDirectory(publicImagesRoot);

  recreateDirectory(outputWebRoot);
  const offlineWebImageMap = copyOfflineWebImages(publicImagesRoot, outputWebImagesRoot);
  copyOfflineWebLogo(outputWebImagesRoot);

  const crags = readCollection('crags');
  const boulders = readCollection('boulders');
  const topos = readCollection('topos');
  const problems = readCollection('problems');
  const settings = readSettings();

  const toposBySlug = mapBySlug(topos);
  const bouldersBySlug = mapBySlug(boulders);

  const bundles = crags.map((crag) => {
    const cragSlug = crag.slug;
    const cragBoulders = boulders.filter((boulder) => boulder.crag === cragSlug);
    const cragBoulderSlugs = new Set(cragBoulders.map((boulder) => boulder.slug));
    const cragTopos = topos.filter((topo) => cragBoulderSlugs.has(topo.boulder));
    const cragTopoSlugs = new Set(cragTopos.map((topo) => topo.slug));
    const cragProblems = problems.filter((problem) => cragTopoSlugs.has(problem.topo));

    const sectors = cragBoulders.map((boulder) => {
      const boulderTopos = cragTopos.filter((topo) => topo.boulder === boulder.slug);
      const boulderTopoSlugs = new Set(boulderTopos.map((topo) => topo.slug));
      const boulderProblems = cragProblems.filter((problem) => boulderTopoSlugs.has(problem.topo));

      return compact({
        slug: boulder.slug,
        cragSlug,
        title: boulder.title ?? '',
        thumbnailUrl: existingImageUrl(boulder.thumbnail),
        description: boulder.description ?? '',
        latitude: numberOrNull(boulder.latitude),
        longitude: numberOrNull(boulder.longitude),
        problemCount: boulderProblems.length,
        safetyNotes: extractSafetyNotes([boulder.description]),
        lastUpdatedAt: generatedAt,
      });
    });

    const routes = cragProblems
      .map((problem) => {
        const topo = toposBySlug.get(problem.topo);
        const boulder = topo ? bouldersBySlug.get(topo.boulder) : undefined;

        return compact({
          slug: problem.slug,
          sectorSlug: boulder?.slug ?? '',
          title: problem.title ?? '',
          grade: problem.grade ?? 'unknown',
          index: numberOrNull(problem.index),
          topoSlug: topo?.slug ?? problem.topo ?? '',
          topoTitle: topo?.title ?? '',
          hashtag: problem.hashtag ?? '',
          fa: problem.fa ?? '',
          imageUrl: existingImageUrl(problem.image),
          description: problem.description ?? '',
          safetyNotes: extractSafetyNotes([problem.description], routeSafetyNote),
          lastUpdatedAt: generatedAt,
        });
      })
      .filter((route) => route.sectorSlug);

    const approachInfo = compact({
      cragSlug,
      address: crag.address ?? '',
      howToGetThere: crag.howToGetThere ?? '',
      parkingSpot: crag.parkingSpot ?? '',
      parkingLatitude: numberOrNull(crag.parkingLatitude),
      parkingLongitude: numberOrNull(crag.parkingLongitude),
      cafeLink: crag.cafeLink ?? '',
      cafeLatitude: numberOrNull(crag.cafeLatitude),
      cafeLongitude: numberOrNull(crag.cafeLongitude),
      safetyNotes: extractSafetyNotes([crag.howToGetThere, crag.description]),
      lastUpdatedAt: generatedAt,
    });

    return {
      crag: compact({
        slug: cragSlug,
        title: crag.title ?? '',
        thumbnailUrl: existingImageUrl(crag.thumbnail),
        difficultyMin: crag.difficultyMin ?? parseDifficulty(crag.difficulty).min,
        difficultyMax: crag.difficultyMax ?? parseDifficulty(crag.difficulty).max,
        description: crag.description ?? '',
        latitude: numberOrNull(crag.latitude),
        longitude: numberOrNull(crag.longitude),
        mapImageUrl: existingImageUrl(crag.mapImage),
        boulderCount: cragBoulders.length,
        problemCount: cragProblems.length,
        safetyNotes: extractSafetyNotes([crag.howToGetThere, crag.description]),
        lastUpdatedAt: generatedAt,
      }),
      sectors,
      routes,
      approachInfo,
      offlineImages: buildOfflineImages({
        crag,
        cragBoulders,
        cragTopos,
        cragProblems,
        toposBySlug,
      }),
    };
  });

  fs.writeFileSync(
    outputWebPath,
    buildOfflineWebHtml({
      bundles,
      generatedAt,
      settings,
      imageMap: offlineWebImageMap,
    }),
  );

  console.log(`Wrote ${path.relative(appRoot, outputWebPath)}`);
  console.log(`Copied ${countFiles(outputWebImagesRoot)} offline web image files`);
  console.log(`Exported ${bundles.length} crags, ${boulders.length} boulders, ${topos.length} topos, ${problems.length} problems`);
}

function readCollection(name) {
  const directory = path.join(contentRoot, name);
  if (!fs.existsSync(directory)) return [];

  return fs
    .readdirSync(directory)
    .filter((fileName) => fileName.endsWith('.md'))
    .sort()
    .map((fileName) => {
      const filePath = path.join(directory, fileName);
      const fileContents = fs.readFileSync(filePath, 'utf8');
      const data = parseFrontmatter(fileContents);
      return {
        slug: data.slug || fileName.replace(/\.md$/, ''),
        ...data,
      };
    });
}

function readSettings() {
  const filePath = path.join(contentRoot, 'settings', 'site.md');
  if (!fs.existsSync(filePath)) {
    return {
      heroImage: '/images/hero-sample.png',
      title: 'Granite',
      slogan: 'DREAM to DREAM!',
    };
  }

  const data = parseFrontmatter(fs.readFileSync(filePath, 'utf8'));
  return {
    heroImage: existingImageUrl(data.heroImage) || '/images/hero-sample.png',
    title: data.title || 'Granite',
    slogan: data.slogan || 'DREAM to DREAM!',
  };
}

function parseFrontmatter(fileContents) {
  const match = fileContents.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!match) return {};

  const lines = match[1].split(/\r?\n/);
  const data = {};

  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    if (!line.trim() || line.trimStart().startsWith('#')) continue;

    const scalarMatch = line.match(/^([A-Za-z0-9_-]+):(?:\s*(.*))?$/);
    if (!scalarMatch) continue;

    const key = scalarMatch[1];
    const rawValue = scalarMatch[2] ?? '';

    if (['|', '|-', '>', '>-'].includes(rawValue.trim())) {
      const blockLines = [];
      while (index + 1 < lines.length && (/^\s+/.test(lines[index + 1]) || lines[index + 1].trim() === '')) {
        index += 1;
        blockLines.push(lines[index].replace(/^  /, ''));
      }
      const separator = rawValue.trim().startsWith('>') ? ' ' : '\n';
      data[key] = blockLines.join(separator).trimEnd();
    } else {
      data[key] = parseScalar(rawValue);
    }
  }

  return data;
}

function parseScalar(value) {
  const trimmed = value.trim();
  if (!trimmed) return '';
  if (trimmed === 'true') return true;
  if (trimmed === 'false') return false;
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    return trimmed.slice(1, -1);
  }
  if (/^-?\d+(?:\.\d+)?$/.test(trimmed)) return Number(trimmed);
  return trimmed;
}

function buildOfflineImages({ crag, cragBoulders, cragTopos, cragProblems, toposBySlug }) {
  const images = [];
  addOfflineImage(images, crag.thumbnail, 'crag', crag.slug, 'thumbnail');
  addOfflineImage(images, crag.mapImage, 'approach', crag.slug, 'map');

  for (const boulder of cragBoulders) {
    addOfflineImage(images, boulder.thumbnail, 'sector', boulder.slug, 'thumbnail');
  }

  for (const problem of cragProblems) {
    const topo = toposBySlug.get(problem.topo);
    addOfflineImage(images, topo?.image, 'route', problem.slug, 'topo');
    addOfflineImage(images, problem.image, 'route', problem.slug, 'route');
  }

  return images;
}

function addOfflineImage(images, assetUrl, ownerType, ownerSlug, imageKind) {
  if (!assetUrl || !assetUrl.startsWith('/images/')) return;

  const fileName = assetUrl.replace('/images/', '');
  const sourcePath = path.join(publicImagesRoot, fileName);
  if (!fs.existsSync(sourcePath)) return;

  const image = {
    assetUrl,
    fileName,
    ownerType,
    ownerSlug,
    imageKind,
    lastUpdatedAt: generatedAt,
  };

  if (!images.some((existing) => existing.assetUrl === image.assetUrl && existing.ownerType === ownerType && existing.ownerSlug === ownerSlug && existing.imageKind === imageKind)) {
    images.push(image);
  }
}

function existingImageUrl(assetUrl) {
  if (!assetUrl || !assetUrl.startsWith('/images/')) return assetUrl ?? '';

  const fileName = assetUrl.replace('/images/', '');
  return fs.existsSync(path.join(publicImagesRoot, fileName)) ? assetUrl : '';
}

function extractSafetyNotes(texts, fallback = defaultSafetyNote) {
  const candidates = texts
    .filter(Boolean)
    .flatMap((text) => String(text).split(/\r?\n/))
    .map((line) => line.trim())
    .filter((line) => /주의|위험|낙석|통제|금지|주차|피해/.test(line));

  const unique = [...new Set(candidates)];
  return unique.length > 0 ? unique : [fallback];
}

function parseDifficulty(value) {
  const fallback = { min: 'V0', max: 'V10' };
  if (!value || typeof value !== 'string') return fallback;
  const match = value.match(/^(V\d+)(?:-(V\d+))?$/);
  if (!match) return fallback;
  return { min: match[1], max: match[2] ?? match[1] };
}

function mapBySlug(items) {
  return new Map(items.map((item) => [item.slug, item]));
}

function numberOrNull(value) {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function compact(value) {
  return Object.fromEntries(
    Object.entries(value).filter(([, entryValue]) => entryValue !== null && entryValue !== undefined),
  );
}

function copyOfflineWebImages(source, destination) {
  fs.mkdirSync(destination, { recursive: true });
  const imageMap = {};

  copyOfflineWebImagesRecursive(source, source, destination, imageMap);

  return imageMap;
}

function copyOfflineWebImagesRecursive(root, source, destination, imageMap) {
  for (const entry of fs.readdirSync(source, { withFileTypes: true })) {
    const sourcePath = path.join(source, entry.name);
    if (entry.isDirectory()) {
      copyOfflineWebImagesRecursive(root, sourcePath, destination, imageMap);
    } else if (entry.isFile()) {
      const assetName = path.relative(root, sourcePath).split(path.sep).join('/');
      const safeName = offlineWebSafeImageName(assetName);
      fs.copyFileSync(sourcePath, path.join(destination, safeName));
      imageMap[assetName] = `images/${safeName}`;
    }
  }
}

function offlineWebSafeImageName(assetName) {
  const extension = path.extname(assetName).toLowerCase() || '.img';
  const digest = crypto.createHash('sha1').update(assetName).digest('hex').slice(0, 20);
  return `img_${digest}${extension}`;
}

function copyOfflineWebLogo(destination) {
  const candidates = [
    path.join(appRoot, 'assets', 'images', 'logo.png'),
    path.join(webRoot, 'public', 'logo.png'),
  ];
  const source = candidates.find((candidate) => fs.existsSync(candidate));
  if (source) fs.copyFileSync(source, path.join(destination, 'logo.png'));
}

function recreateDirectory(directory) {
  fs.rmSync(directory, { recursive: true, force: true });
  fs.mkdirSync(directory, { recursive: true });
}

function countFiles(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).filter((entry) => entry.isFile()).length;
}

function assertDirectory(directory) {
  if (!fs.existsSync(directory) || !fs.statSync(directory).isDirectory()) {
    throw new Error(`Directory not found: ${directory}`);
  }
}

function buildOfflineWebHtml({ bundles, generatedAt, settings, imageMap }) {
  return `<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <title>Granite Offline</title>
  <style>${offlineWebCss()}</style>
</head>
<body>
  <div id="app"></div>
  <script id="granite-seed" type="application/json">${escapeHtml(
    JSON.stringify({ generatedAt, settings, bundles }),
  )}</script>
  <script>${offlineWebJs(imageMap)}</script>
</body>
</html>
`;
}

function offlineWebCss() {
  return `
:root {
  --app-max-width: 430px;
  --primary-color: #333;
  --secondary-color: #666;
  --background: #fafafa;
  --card-background: #fff;
}
* { box-sizing: border-box; margin: 0; padding: 0; }
html { display: flex; justify-content: center; background: #e0e0e0; min-height: 100%; }
body { position: relative; width: 100%; max-width: var(--app-max-width); min-height: 100vh; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, sans-serif; background: var(--background); color: var(--primary-color); line-height: 1.6; overflow-x: clip; }
@media (max-width: 430px) { html { background: var(--background); } body { max-width: 100%; } }
#app { min-height: 100vh; background: var(--background); }
a { color: inherit; text-decoration: none; }
button { font: inherit; cursor: pointer; }
.pageBanner { position: relative; width: 100%; height: 140px; overflow: hidden; }
.pageBanner .bannerImage { width: 100%; height: 100%; object-fit: cover; display: block; }
.pageBanner .overlay { position: absolute; bottom: 0; left: 0; right: 0; padding: 16px; background: linear-gradient(transparent, rgba(0, 0, 0, .6)); }
.pageBanner .title { color: #fff; font-size: 1.5rem; font-weight: 700; display: flex; align-items: center; gap: 6px; margin: 0; }
.pageBanner .icon { font-size: 1.25rem; }
.cragListSection { padding: 24px 16px; background-color: #f5f5f5; min-height: calc(100vh - 140px - 150px); }
.cragList { display: flex; flex-direction: column; gap: 32px; }
.cragCard { display: block; text-decoration: none; color: inherit; }
.imageWrapper { width: 100%; aspect-ratio: 4 / 3; border-radius: 8px; overflow: hidden; margin-bottom: 12px; background: #eee; }
.imageWrapper img { width: 100%; height: 100%; object-fit: cover; display: block; }
.info { padding: 0 4px; }
.title { font-size: 1.1rem; font-weight: 600; color: #333; margin: 0 0 4px 0; }
.meta { font-size: .85rem; color: #666; margin: 0; }

.cragDetailBanner { position: relative; width: 100%; height: 200px; overflow: hidden; background: #ddd; }
.cragDetailBanner .image { width: 100%; height: 100%; object-fit: cover; display: block; }
.cragDetailBanner .overlay { position: absolute; bottom: 0; left: 0; right: 0; padding: 24px 16px; background: linear-gradient(transparent, rgba(0, 0, 0, .8)); text-align: center; }
.cragDetailBanner .cragDetailTitle { color: #fff; font-size: 1.5rem; font-weight: 700; margin: 0 0 8px 0; }
.cragDetailBanner .description { color: rgba(255, 255, 255, .9); font-size: .8rem; line-height: 1.5; margin: 0; }
.cragTabsContainer { background-color: #fff; }
.tabs { display: flex; border-bottom: 1px solid #e0e0e0; padding: 0 16px; background: #fff; }
.tab { flex: 1; padding: 14px 8px; font-size: .9rem; font-weight: 500; color: #999; background: none; border: none; position: relative; transition: color .2s; }
.tab:hover { color: #666; }
.tab.active { color: #333; }
.tab.active::after { content: ""; position: absolute; bottom: -1px; left: 0; right: 0; height: 2px; background-color: #333; }
.content { padding: 24px 16px; min-height: 400px; }
.infoTab { display: flex; flex-direction: column; gap: 24px; }
.summary { text-align: center; font-size: 1rem; font-weight: 500; color: #333; padding-bottom: 16px; border-bottom: 1px solid #eee; }
.mapPreview { position: relative; border-radius: 12px; overflow: hidden; aspect-ratio: 16 / 10; }
.mapImage { width: 100%; height: 100%; object-fit: cover; display: block; }
.mapPlaceholder, .mapLoading { width: 100%; height: 100%; min-height: 200px; display: flex; align-items: center; justify-content: center; background: #f5f5f5; color: #999; text-align: center; font-size: .85rem; }
.infoList { display: flex; flex-direction: column; gap: 20px; }
.infoItem { display: flex; gap: 12px; align-items: flex-start; }
.infoIcon { flex-shrink: 0; color: #666; width: 20px; }
.infoContent { flex: 1; }
.infoLabel { font-size: .85rem; font-weight: 600; color: #333; margin-bottom: 4px; }
.infoValue, .infoValueMultiline { font-size: .85rem; color: #666; line-height: 1.5; }
.infoValueMultiline { white-space: pre-line; }
.buttons { display: flex; gap: 12px; margin-top: 8px; }
.button { display: inline-flex; align-items: center; gap: 8px; padding: 10px 20px; border: 1px solid #ddd; border-radius: 24px; font-size: .85rem; font-weight: 500; color: #333; background: #fff; transition: all .2s; }
.button:hover { background: #f5f5f5; border-color: #ccc; }
.placeholderTab { display: flex; flex-direction: column; align-items: center; justify-content: center; min-height: 200px; color: #999; text-align: center; }
.placeholderInfo { font-size: .85rem; margin-top: 8px; }
.mapTab { margin: -24px -16px; }
.mapTab img { width: 100%; height: auto; display: block; }
.boulderTab { display: flex; flex-direction: column; gap: 16px; }
.boulderList { display: flex; flex-direction: column; gap: 24px; }
.boulderCard { display: flex; flex-direction: column; cursor: pointer; transition: transform .2s; border: none; background: transparent; text-align: left; color: inherit; }
.boulderCard:hover { transform: translateY(-2px); }
.boulderImage { position: relative; width: 100%; aspect-ratio: 16 / 9; border-radius: 8px; overflow: hidden; margin-bottom: 12px; background: #c0c0c0; }
.boulderImage img { width: 100%; height: 100%; object-fit: cover; display: block; }
.boulderInfo { padding: 0 4px; }
.boulderTitle { font-size: 1.1rem; font-weight: 600; color: #333; margin: 0 0 4px 0; }
.boulderMeta { font-size: .85rem; color: #999; margin: 0; }
.routeTab { display: flex; flex-direction: column; gap: 16px; }
.routeHeader { display: flex; align-items: center; justify-content: space-between; padding: 12px 0; border-bottom: 1px solid #e0e0e0; }
.selectedBoulderTitle { font-size: 1.1rem; font-weight: 600; color: #333; margin: 0; }
.showAllButton { display: flex; align-items: center; gap: 4px; padding: 6px 12px; background: none; border: none; font-size: .85rem; font-weight: 400; color: #666; transition: color .2s; }
.showAllButton:hover { color: #333; }
.showAllButton .arrow { font-size: .9rem; }
.searchBox { position: relative; display: flex; align-items: center; }
.searchIcon { position: absolute; left: 12px; color: #999; }
.searchInput { width: 100%; padding: 12px 12px 12px 40px; border: 1px solid #e0e0e0; border-radius: 8px; font-size: .9rem; outline: none; transition: border-color .2s; }
.searchInput:focus { border-color: #999; }
.searchInput::placeholder { color: #bbb; }
.routeTable { border-top: 1px solid #e0e0e0; }
.routeHeaderCell { font-size: .8rem; font-weight: 600; color: #666; background: none; border: none; text-align: left; display: flex; align-items: center; gap: 4px; }
.sortArrow { font-size: .7rem; color: #999; }
.routeList { display: flex; flex-direction: column; }
.routeRow { display: flex; padding: 14px 0; border-bottom: 1px solid #f0f0f0; text-decoration: none; color: inherit; transition: background-color .2s; }
.routeRow:hover { background-color: #f9f9f9; }
.routeCell { font-size: .85rem; color: #333; }
.routeColumn { flex: 2; }
.gradeColumn { flex: 1; text-align: center; }
.boulderColumn { flex: 1.5; text-align: left; color: #999; }

.boulderDetailContainer { background-color: #fff; min-height: 100dvh; display: flex; flex-direction: column; overflow: hidden; }
.navigation { display: flex; align-items: center; justify-content: space-between; padding: 16px 16px; border-bottom: 1px solid #eee; position: sticky; top: 0; background: #fff; z-index: 10; transition: transform .3s ease; }
.navButton { display: flex; align-items: center; justify-content: center; width: 40px; height: 40px; color: #333; text-decoration: none; border-radius: 50%; transition: background-color .2s; border: none; background: #fff; }
.navButton:hover { background-color: #f5f5f5; }
.navButtonPlaceholder { width: 40px; height: 40px; }
.navTitle { font-size: 1rem; font-weight: 600; color: #333; }
.imageSection { position: relative; width: 100%; aspect-ratio: 4 / 3; overflow: hidden; background: #f0f0f0; flex-shrink: 0; z-index: 5; }
.topoImage { width: 100%; height: 100%; object-fit: cover; display: block; }
.topoNavigation { display: flex; align-items: center; justify-content: space-between; padding: 16px; border-bottom: 1px solid #eee; background: #fff; flex-shrink: 0; position: relative; z-index: 6; }
.topoNavButton { display: flex; align-items: center; justify-content: center; width: 32px; height: 32px; color: #333; background: none; border: none; transition: opacity .2s; }
.topoNavButton:active { opacity: .6; }
.topoNavButtonPlaceholder { width: 32px; height: 32px; }
.topoInfo { flex: 1; text-align: center; }
.problemList { padding: 0 16px; flex: 1; overflow-y: auto; -webkit-overflow-scrolling: touch; background: #fff; }
.problemImageContainer { margin-top: 12px; border-radius: 8px; overflow: hidden; }
.problemImage { width: 100%; height: auto; display: block; }
.emptyState { display: flex; align-items: center; justify-content: center; min-height: 200px; color: #999; text-align: center; }
.problemItem { display: flex; gap: 16px; padding: 20px 0; border-bottom: 1px solid #f0f0f0; align-items: flex-start; cursor: pointer; transition: background-color .2s; }
.problemItem:hover { background-color: #f9f9f9; }
.problemItem:last-child { border-bottom: none; }
.problemItemActive { background-color: #f0f0f0; }
.problemNumber { flex-shrink: 0; padding-top: 2px; }
.numberCircle { display: flex; align-items: center; justify-content: center; width: 28px; height: 28px; border-radius: 50%; background-color: #333; color: #fff; font-size: .8rem; font-weight: 600; }
.problemInfo { flex: 1; min-width: 0; }
.problemHeader { display: flex; align-items: baseline; justify-content: space-between; gap: 12px; }
.problemTitle { font-size: 1rem; font-weight: 600; color: #333; margin: 0; line-height: 1.4; }
.problemGrade { flex-shrink: 0; font-size: 1rem; font-weight: 600; color: #333; }
.problemSubInfo { margin-top: 4px; display: flex; flex-direction: column; gap: 2px; }
.problemFa, .problemBoulder { font-size: .8rem; color: #999; }
.problemDescription { font-size: .8rem; color: #bbb; margin-top: 2px; white-space: pre-line; }
.problemMeta { margin-top: 6px; display: flex; align-items: center; justify-content: space-between; gap: 8px; }
.betaButton { display: inline-flex; align-items: center; gap: 5px; padding: 5px 12px; border: none; border-radius: 14px; font-size: .75rem; font-weight: 500; color: #333; background: #efefef; white-space: nowrap; cursor: pointer; transition: background .2s; }
.betaButton:hover { background: #e0e0e0; }

.sheetOverlay { position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0, 0, 0, 0); z-index: 1000; transition: background .3s; }
.sheetOverlayVisible { background: rgba(0, 0, 0, .4); }
.sheet { position: fixed; left: 0; right: 0; bottom: 0; width: 100%; max-width: var(--app-max-width); margin: 0 auto; background: #fff; border-radius: 16px 16px 0 0; max-height: 85vh; overflow-y: auto; transform: translateY(100%); transition: transform .3s ease-out; z-index: 1001; }
.sheetVisible { transform: translateY(0); }
.sheetHandle { width: 36px; height: 4px; background: #ddd; border-radius: 2px; margin: 10px auto 0; }
.sheetHeader { display: flex; align-items: center; justify-content: space-between; padding: 16px 20px 12px; }
.sheetTitle { font-size: 1.1rem; font-weight: 700; color: #333; margin: 0; }
.sheetClose { display: flex; align-items: center; justify-content: center; width: 32px; height: 32px; border: none; background: none; color: #333; cursor: pointer; padding: 0; }
.sheetBody { padding: 0 20px 20px; }
.sheetDescription { font-size: .85rem; color: #666; line-height: 1.6; margin: 0 0 16px 0; }
`;
}

function offlineWebJs(imageMap) {
  return `
const seed = JSON.parse(document.getElementById('granite-seed').textContent);
const offlineImageMap = ${JSON.stringify(imageMap)};
const app = document.getElementById('app');
const state = { route: parseRoute(), tab: 'info', selectedBoulder: null, search: '', sortBy: 'grade', sortOrder: 'asc' };

window.addEventListener('hashchange', () => {
  const nextRoute = parseRoute();
  const changedPage = state.route.name !== nextRoute.name || state.route.cragSlug !== nextRoute.cragSlug;
  state.route = nextRoute;
  if (changedPage || nextRoute.name !== 'crag') {
    state.tab = 'info';
    state.selectedBoulder = null;
    state.search = '';
  }
  render();
});

function parseRoute() {
  const rawHash = location.hash.replace(/^#\\/?/, '');
  const [pathPart, queryPart = ''] = rawHash.split('?');
  const parts = pathPart.split('/').filter(Boolean).map(decodePart);
  const params = new URLSearchParams(queryPart);
  if (parts[0] === 'crag' && parts[2] === 'boulder') {
    return {
      name: 'boulder',
      cragSlug: parts[1],
      boulderSlug: parts[3],
      topoSlug: params.get('topo') ? decodePart(params.get('topo')) : null,
      routeSlug: params.get('route') ? decodePart(params.get('route')) : null,
    };
  }
  if (parts[0] === 'crag') return { name: 'crag', cragSlug: parts[1] };
  return { name: 'home' };
}

function decodePart(value) {
  try { return decodeURIComponent(value ?? ''); } catch (_) { return value ?? ''; }
}

function imagePath(assetUrl) {
  if (!assetUrl) return '';
  if (assetUrl.startsWith('/images/')) return offlineImagePath(assetUrl.replace('/images/', ''));
  return assetUrl;
}

function h(value) {
  return String(value ?? '').replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' }[char]));
}
function currentBundle(slug) { return seed.bundles.find((bundle) => bundle.crag.slug === slug); }
function sectorRoutes(bundle, sectorSlug) { return bundle.routes.filter((route) => route.sectorSlug === sectorSlug); }
function ownerImagePath(bundle, ownerType, ownerSlug, kind) {
  const image = bundle.offlineImages.find((item) => item.ownerType === ownerType && item.ownerSlug === ownerSlug && item.imageKind === kind);
  return image ? offlineImagePath(image.fileName) : '';
}

function offlineImagePath(fileName) {
  return offlineImageMap[fileName] || '';
}

function layout(content) { return content; }

function difficultyText(crag) {
  if (crag.difficultyMin === crag.difficultyMax) return crag.difficultyMin;
  return \`\${crag.difficultyMin}-\${crag.difficultyMax}\`;
}

function sectorBySlug(bundle, sectorSlug) {
  return bundle.sectors.find((sector) => sector.slug === sectorSlug);
}

function routeBoulderTitle(bundle, route) {
  return sectorBySlug(bundle, route.sectorSlug)?.title ?? '';
}

function gradeNumber(grade) {
  const match = String(grade ?? '').match(/V(\\d+)/i);
  return match ? Number(match[1]) : 0;
}

function topoGroups(bundle, sector) {
  const groups = [];
  for (const route of sectorRoutes(bundle, sector.slug)) {
    const slug = route.topoSlug || 'default';
    let group = groups.find((item) => item.slug === slug);
    if (!group) {
      group = {
        slug,
        title: route.topoTitle || sector.title,
        image: ownerImagePath(bundle, 'route', route.slug, 'topo') || imagePath(route.imageUrl) || imagePath(sector.thumbnailUrl),
        routes: [],
      };
      groups.push(group);
    }
    if (!group.image) {
      group.image = ownerImagePath(bundle, 'route', route.slug, 'topo') || imagePath(route.imageUrl) || imagePath(sector.thumbnailUrl);
    }
    group.routes.push(route);
  }
  return groups;
}

function boulderDetailHash(cragSlug, boulderSlug, params = {}) {
  const query = new URLSearchParams();
  if (params.topoSlug) query.set('topo', params.topoSlug);
  if (params.routeSlug) query.set('route', params.routeSlug);
  const queryString = query.toString();
  return \`#/crag/\${encodeURIComponent(cragSlug)}/boulder/\${encodeURIComponent(boulderSlug)}\${queryString ? '?' + queryString : ''}\`;
}

function bindOfflineBetaButtons() {
  document.querySelectorAll('[data-beta-button]').forEach((button) => {
    button.addEventListener('click', (event) => {
      event.preventDefault();
      event.stopPropagation();
      openOfflineBetaSheet({
        title: button.dataset.problemTitle || 'Beta',
        grade: button.dataset.problemGrade || '',
      });
    });
  });
}

function openOfflineBetaSheet(problem) {
  closeOfflineBetaSheet({ immediate: true });

  const root = document.createElement('div');
  root.setAttribute('data-beta-sheet-root', '');
  root.innerHTML = [
    '<div class="sheetOverlay" data-beta-sheet-close></div>',
    '<div class="sheet">',
    '<div class="sheetHandle"></div>',
    '<div class="sheetHeader">',
    '<h2 class="sheetTitle">' + h(problem.title) + (problem.grade ? ' ' + h(problem.grade) : '') + '</h2>',
    '<button class="sheetClose" type="button" data-beta-sheet-close aria-label="닫기">✕</button>',
    '</div>',
    '<div class="sheetBody">',
    '<p class="sheetDescription">현재 오프라인 상태라 베타 영상을 사용할 수 없습니다.</p>',
    '<p class="sheetDescription">네트워크에 연결한 뒤 다시 시도해 주세요.</p>',
    '</div>',
    '</div>',
  ].join('');

  document.body.appendChild(root);
  document.body.style.overflow = 'hidden';

  const overlay = root.querySelector('.sheetOverlay');
  const sheet = root.querySelector('.sheet');
  root.querySelectorAll('[data-beta-sheet-close]').forEach((element) => {
    element.addEventListener('click', closeOfflineBetaSheet);
  });

  setTimeout(() => {
    overlay?.classList.add('sheetOverlayVisible');
    sheet?.classList.add('sheetVisible');
  }, 10);
}

function closeOfflineBetaSheet(options = {}) {
  const root = document.querySelector('[data-beta-sheet-root]');
  if (!root) return;

  if (options.immediate) {
    root.remove();
    return;
  }

  root.querySelector('.sheetOverlay')?.classList.remove('sheetOverlayVisible');
  root.querySelector('.sheet')?.classList.remove('sheetVisible');
  document.body.style.overflow = '';

  setTimeout(() => root.remove(), 300);
}

function render() {
  if (state.route.name === 'crag') return renderCrag(state.route.cragSlug);
  if (state.route.name === 'boulder') return renderBoulder(state.route.cragSlug, state.route.boulderSlug);
  return renderHome();
}

function renderHome() {
  const cards = seed.bundles.map((bundle) => {
    const crag = bundle.crag;
    return \`<a class="cragCard" href="#/crag/\${encodeURIComponent(crag.slug)}">
      <div class="imageWrapper"><img src="\${imagePath(crag.thumbnailUrl)}" alt="\${h(crag.title)}"></div>
      <div class="info"><h3 class="title">\${h(crag.title)}</h3><p class="meta">\${bundle.routes.length} problems · \${h(difficultyText(crag))}</p></div>
    </a>\`;
  }).join('');
  app.innerHTML = layout(\`<main>
    <section class="pageBanner"><img src="\${imagePath(seed.settings?.heroImage || '')}" alt="Crag" class="bannerImage"><div class="overlay"><h1 class="title"><span class="icon">📍</span>Crag</h1></div></section>
    <section class="cragListSection"><div class="cragList">\${cards}</div></section>
  </main>\`);
}

function renderCrag(slug) {
  const bundle = currentBundle(slug);
  if (!bundle) return renderHome();
  const crag = bundle.crag;
  const tabHtml = ['info', 'boulder', 'route', 'map', 'travel'].map((tab) => {
    const label = ({ info: 'Info', boulder: 'Boulder', route: 'Route', map: 'Map', travel: 'Travel' })[tab];
    return \`<button class="tab \${state.tab === tab ? 'active' : ''}" data-tab="\${tab}">\${label}</button>\`;
  }).join('');
  app.innerHTML = layout(\`
    <div class="cragDetailBanner"><img src="\${imagePath(crag.thumbnailUrl)}" alt="\${h(crag.title)}" class="image"><div class="overlay"><h1 class="cragDetailTitle">\${h(crag.title)}</h1><p class="description">\${h(crag.description || '')}</p></div></div>
    <div class="cragTabsContainer">
      <div class="tabs">\${tabHtml}</div>
      <div class="content">\${renderCragTab(bundle)}</div>
    </div>
  \`);
  document.querySelectorAll('[data-tab]').forEach((button) => {
    button.addEventListener('click', () => {
      state.tab = button.dataset.tab;
      if (state.tab !== 'route') state.selectedBoulder = null;
      renderCrag(slug);
    });
  });
  document.querySelectorAll('[data-boulder-filter]').forEach((card) => {
    card.addEventListener('click', () => {
      state.selectedBoulder = card.dataset.boulderFilter;
      state.tab = 'route';
      renderCrag(slug);
    });
  });
  const searchInput = document.querySelector('[data-search-input]');
  if (searchInput) {
    searchInput.addEventListener('input', (event) => {
      state.search = event.target.value;
      renderCrag(slug);
      const nextInput = document.querySelector('[data-search-input]');
      if (nextInput) {
        nextInput.focus();
        nextInput.setSelectionRange(nextInput.value.length, nextInput.value.length);
      }
    });
  }
  document.querySelectorAll('[data-sort]').forEach((button) => {
    button.addEventListener('click', () => {
      const nextSort = button.dataset.sort;
      if (state.sortBy === nextSort) {
        state.sortOrder = state.sortOrder === 'asc' ? 'desc' : 'asc';
      } else {
        state.sortBy = nextSort;
        state.sortOrder = 'asc';
      }
      renderCrag(slug);
    });
  });
  document.querySelectorAll('[data-clear-boulder-filter]').forEach((button) => {
    button.addEventListener('click', () => {
      state.selectedBoulder = null;
      renderCrag(slug);
    });
  });
}

function renderCragTab(bundle) {
  if (state.tab === 'boulder') return renderBoulderTab(bundle);
  if (state.tab === 'route') return renderRouteTab(bundle);
  if (state.tab === 'map') return renderMapTab(bundle);
  if (state.tab === 'travel') return '<div class="placeholderTab"><p>등록된 게시물이 없습니다.</p></div>';
  return renderInfoTab(bundle);
}

function renderInfoTab(bundle) {
  const crag = bundle.crag;
  const mapImage = crag.mapImageUrl ? imagePath(crag.mapImageUrl) : '';
  return \`<div class="infoTab">
    <div class="summary">\${bundle.sectors.length} boulders · \${bundle.routes.length} problems</div>
    <div class="mapPreview">\${mapImage ? \`<img src="\${mapImage}" alt="지도" class="mapImage">\` : \`<div class="mapPlaceholder"><span>지도 준비중</span></div>\`}</div>
    <div class="infoList">
      <div class="infoItem"><div class="infoIcon"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"></path><circle cx="12" cy="10" r="3"></circle></svg></div><div class="infoContent"><div class="infoLabel">Address</div><div class="infoValue">\${h(bundle.approachInfo.address || '주소 정보 없음')}</div></div></div>
      <div class="infoItem"><div class="infoIcon"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"></circle><path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"></path><line x1="12" y1="17" x2="12.01" y2="17"></line></svg></div><div class="infoContent"><div class="infoLabel">How to get there?</div><div class="infoValueMultiline">\${h(bundle.approachInfo.howToGetThere || '정보 없음')}</div></div></div>
    </div>
    <div class="buttons">
      \${bundle.approachInfo.parkingLatitude && bundle.approachInfo.parkingLongitude ? '<span class="button">Parking Spot</span>' : ''}
      \${bundle.approachInfo.cafeLatitude && bundle.approachInfo.cafeLongitude ? '<span class="button">Cafe</span>' : ''}
    </div>
  </div>\`;
}

function renderBoulderTab(bundle) {
  if (bundle.sectors.length === 0) return '<div class="placeholderTab"><p>등록된 볼더가 없습니다.</p></div>';
  const cards = bundle.sectors.map((sector) => \`<button class="boulderCard" data-boulder-filter="\${h(sector.slug)}">
    <div class="boulderImage">\${sector.thumbnailUrl ? \`<img src="\${imagePath(sector.thumbnailUrl)}" alt="\${h(sector.title)}">\` : '<div class="boulderImagePlaceholder"></div>'}</div>
    <div class="boulderInfo"><h3 class="boulderTitle">\${h(sector.title)}</h3><p class="boulderMeta">\${sectorRoutes(bundle, sector.slug).length} problems · \${h(difficultyText(bundle.crag))}</p></div>
  </button>\`).join('');
  return \`<div class="boulderTab"><div class="boulderList">\${cards}</div></div>\`;
}

function renderRouteTab(bundle) {
  if (bundle.routes.length === 0) return '<div class="placeholderTab"><p>등록된 루트가 없습니다.</p></div>';
  const selectedSector = state.selectedBoulder ? sectorBySlug(bundle, state.selectedBoulder) : null;
  const search = state.search.trim().toLowerCase();
  const filteredRoutes = bundle.routes
    .filter((route) => !state.selectedBoulder || route.sectorSlug === state.selectedBoulder)
    .filter((route) => !search || route.title.toLowerCase().includes(search) || route.grade.toLowerCase().includes(search));
  const sortedRoutes = [...filteredRoutes].sort((a, b) => {
    if (state.sortBy === 'grade') {
      const result = gradeNumber(a.grade) - gradeNumber(b.grade);
      return state.sortOrder === 'asc' ? result : -result;
    }
    const result = routeBoulderTitle(bundle, a).localeCompare(routeBoulderTitle(bundle, b));
    return state.sortOrder === 'asc' ? result : -result;
  });
  const rows = sortedRoutes.map((route, index) => \`<a class="routeRow" href="\${boulderDetailHash(bundle.crag.slug, route.sectorSlug, { topoSlug: route.topoSlug, routeSlug: route.slug })}">
    <div class="routeCell routeColumn">\${h(route.title)}</div>
    <div class="routeCell gradeColumn">\${h(route.grade)}</div>
    <div class="routeCell boulderColumn">\${h(routeBoulderTitle(bundle, route))}</div>
  </a>\`).join('');
  return \`<div class="routeTab">
    \${selectedSector ? \`<div class="routeHeader"><h3 class="selectedBoulderTitle">\${h(selectedSector.title)}</h3><button class="showAllButton" data-clear-boulder-filter>Route All <span class="arrow">→</span></button></div>\` : ''}
    <div class="searchBox">
      <svg class="searchIcon" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"></circle><path d="m21 21-4.35-4.35"></path></svg>
      <input type="text" placeholder="루트 이름 검색, 난이도 검색" value="\${h(state.search)}" class="searchInput" data-search-input>
    </div>
    <div class="routeTable">
      <div class="routeHeader">
        <button class="routeHeaderCell routeColumn" data-sort="boulder">Route \${state.sortBy === 'boulder' ? \`<span class="sortArrow">\${state.sortOrder === 'asc' ? '▼' : '▲'}</span>\` : ''}</button>
        <button class="routeHeaderCell gradeColumn" data-sort="grade">Grade \${state.sortBy === 'grade' ? \`<span class="sortArrow">\${state.sortOrder === 'asc' ? '▼' : '▲'}</span>\` : ''}</button>
        <div class="routeHeaderCell boulderColumn">Boulder</div>
      </div>
      <div class="routeList">\${rows || '<div class="emptyState">검색 결과가 없습니다.</div>'}</div>
    </div>
  </div>\`;
}

function renderMapTab(bundle) {
  const crag = bundle.crag;
  if (!crag.mapImageUrl) return '<div class="placeholderTab"><p>지도가 준비중입니다.</p></div>';
  return \`<div class="mapTab"><img src="\${imagePath(crag.mapImageUrl)}" alt="약도"></div>\`;
}

function renderBoulder(cragSlug, boulderSlug) {
  const bundle = currentBundle(cragSlug);
  if (!bundle) return renderHome();
  const sector = bundle.sectors.find((item) => item.slug === boulderSlug);
  if (!sector) return renderCrag(cragSlug);
  const groups = topoGroups(bundle, sector);
  if (groups.length === 0) {
    app.innerHTML = \`<div class="boulderDetailContainer"><div class="navigation"><a href="#/crag/\${encodeURIComponent(cragSlug)}" class="navButton">‹</a><span class="navTitle">\${h(bundle.crag.title)}</span><div class="navButtonPlaceholder"></div></div><div class="emptyState">등록된 토포가 없습니다.</div></div>\`;
    return;
  }
  const routeFromHash = groups.flatMap((group) => group.routes).find((route) => route.slug === state.route.routeSlug);
  const requestedTopoSlug = routeFromHash?.topoSlug || state.route.topoSlug;
  const topoIndex = Math.max(0, groups.findIndex((group) => group.slug === requestedTopoSlug));
  const currentTopo = groups[topoIndex] || groups[0];
  const selectedRoute = currentTopo.routes.find((route) => route.slug === state.route.routeSlug);
  const selectedImage = selectedRoute ? ownerImagePath(bundle, 'route', selectedRoute.slug, 'route') || imagePath(selectedRoute.imageUrl) : '';
  const image = selectedImage || currentTopo.image || imagePath(sector.thumbnailUrl);
  const prevTopo = topoIndex > 0 ? groups[topoIndex - 1] : null;
  const nextTopo = topoIndex < groups.length - 1 ? groups[topoIndex + 1] : null;
  const routeRows = currentTopo.routes.map((route, index) => \`<a class="problemItem \${selectedRoute?.slug === route.slug ? 'problemItemActive' : ''}" href="\${boulderDetailHash(cragSlug, boulderSlug, { topoSlug: currentTopo.slug, routeSlug: route.slug })}">
    <div class="problemNumber"><div class="numberCircle">\${route.index || index + 1}</div></div>
    <div class="problemInfo">
      <div class="problemHeader"><h3 class="problemTitle">\${h(route.title)}</h3><span class="problemGrade">\${h(route.grade)}</span></div>
      <div class="problemSubInfo">\${route.fa ? \`<div class="problemFa">FA: \${h(route.fa)}</div>\` : ''}\${route.description ? \`<div class="problemDescription">\${h(route.description)}</div>\` : ''}</div>
      <div class="problemMeta"><button class="betaButton" type="button" data-beta-button data-problem-title="\${h(route.title)}" data-problem-grade="\${h(route.grade)}"><span>▶</span> beta</button></div>
    </div>
  </a>\`).join('');
  app.innerHTML = \`<div class="boulderDetailContainer">
    <div class="navigation"><a href="#/crag/\${encodeURIComponent(cragSlug)}" class="navButton" aria-label="뒤로"><svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="15 18 9 12 15 6"></polyline></svg></a><span class="navTitle">\${h(bundle.crag.title)}</span><div class="navButtonPlaceholder"></div></div>
    <div class="imageSection"><img src="\${image}" alt="\${h(selectedRoute?.title || currentTopo.title || sector.title)}" class="topoImage"></div>
    <div class="topoNavigation">
      \${prevTopo ? \`<a href="\${boulderDetailHash(cragSlug, boulderSlug, { topoSlug: prevTopo.slug })}" class="topoNavButton"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="15 18 9 12 15 6"></polyline></svg></a>\` : '<div class="topoNavButtonPlaceholder"></div>'}
      <div class="topoInfo"><div class="boulderTitle">\${h(sector.title)} \${topoIndex + 1}/\${groups.length}</div></div>
      \${nextTopo ? \`<a href="\${boulderDetailHash(cragSlug, boulderSlug, { topoSlug: nextTopo.slug })}" class="topoNavButton"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="9 18 15 12 9 6"></polyline></svg></a>\` : '<div class="topoNavButtonPlaceholder"></div>'}
    </div>
    <div class="problemList">\${routeRows || '<div class="emptyState">등록된 문제가 없습니다.</div>'}</div>
  </div>\`;
  bindOfflineBetaButtons();
}

render();
`;
}

function escapeHtml(value) {
  return value.replace(/[&<]/g, (char) => ({ '&': '&amp;', '<': '&lt;' }[char]));
}
