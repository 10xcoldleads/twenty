import { captureExceptionWithoutThrowing } from '~/utils/captureExceptionWithoutThrowing';

let preloadScheduled = false;

const preload = () => {
  import('@/navigation-menu-item/display/dnd/providers/NavigationMenuItemDndKitProvider').catch(
    captureExceptionWithoutThrowing,
  );
  import('@/navigation-menu-item/display/sections/workspace/components/WorkspaceSectionListDndKit').catch(
    captureExceptionWithoutThrowing,
  );
};

export const preloadNavigationMenuItemDndKit = (): void => {
  if (preloadScheduled) {
    return;
  }
  preloadScheduled = true;
  preload();
};
