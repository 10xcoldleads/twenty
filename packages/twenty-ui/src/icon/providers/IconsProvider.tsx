import { type JSX, useEffect, useState } from 'react';

import { IconsContext } from '@ui/icon/internal/IconsContext';
import { type IconComponent } from '@ui/icon/types/IconComponent';

type IconsProviderProps = {
  children: JSX.Element;
};

export const IconsProvider = ({ children }: IconsProviderProps) => {
  const [icons, setIcons] = useState<Record<string, IconComponent>>({});

  useEffect(() => {
    import('./internal/AllIcons')
      .then(({ ALL_ICONS }) => {
        setIcons(ALL_ICONS);
      })
      .catch((error) => {
        // oxlint-disable-next-line no-console
        console.error('Failed to load icons:', error);
      });
  }, []);

  return (
    <IconsContext.Provider value={icons}>{children}</IconsContext.Provider>
  );
};
