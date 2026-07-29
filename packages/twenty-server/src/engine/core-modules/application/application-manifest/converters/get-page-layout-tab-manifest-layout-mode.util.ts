import { type PageLayoutTabManifest } from 'twenty-shared/application';
import { PageLayoutTabLayoutMode } from 'twenty-shared/types';

export const getPageLayoutTabManifestLayoutMode = (
  pageLayoutTabManifest: PageLayoutTabManifest,
): PageLayoutTabLayoutMode =>
  pageLayoutTabManifest.layoutMode ?? PageLayoutTabLayoutMode.GRID;
