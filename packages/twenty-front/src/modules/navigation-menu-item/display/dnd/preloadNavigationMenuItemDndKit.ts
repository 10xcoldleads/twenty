let preloadScheduled = false;

const preload = () => {
  import('@/navigation-menu-item/display/dnd/providers/NavigationMenuItemDndKitProvider').catch(
    () => undefined,
  );
  import('@/navigation-menu-item/display/sections/workspace/components/WorkspaceSectionListDndKit').catch(
    () => undefined,
  );
};

export const preloadNavigationMenuItemDndKit = (): void => {
  if (preloadScheduled) {
    return;
  }
  preloadScheduled = true;
  preload();
};
