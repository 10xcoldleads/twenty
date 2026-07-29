import {
  type PageLayoutTabManifest,
  type PageLayoutWidgetManifest,
} from 'twenty-shared/application';
import { PageLayoutTabLayoutMode } from 'twenty-shared/types';

const validateWidget = ({
  widget,
  layoutMode,
}: {
  widget: PageLayoutWidgetManifest;
  layoutMode: PageLayoutTabLayoutMode;
}): string[] => {
  const errors: string[] = [];

  if (!widget.universalIdentifier) {
    errors.push('PageLayoutWidget must have a universalIdentifier');
  }

  if (!widget.title) {
    errors.push('PageLayoutWidget must have a title');
  }

  if (!widget.type) {
    errors.push('PageLayoutWidget must have a type');
  }

  if (widget.position && widget.position.layoutMode !== layoutMode) {
    errors.push(
      `PageLayoutWidget position layoutMode "${widget.position.layoutMode}" does not match its tab layoutMode "${layoutMode}"`,
    );
  }

  return errors;
};

export const validatePageLayoutTabWidgets = (
  tab: Pick<PageLayoutTabManifest, 'layoutMode' | 'widgets'>,
): string[] =>
  (tab.widgets ?? []).flatMap((widget) =>
    validateWidget({
      widget,
      layoutMode: tab.layoutMode ?? PageLayoutTabLayoutMode.GRID,
    }),
  );
