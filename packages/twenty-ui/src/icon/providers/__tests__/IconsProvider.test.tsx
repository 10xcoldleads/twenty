import { render, screen, waitFor } from '@testing-library/react';

import { IconsProvider } from '@ui/icon/providers/IconsProvider';

jest.mock('@ui/icon/providers/internal/AllIcons', () => ({
  get ALL_ICONS() {
    throw new Error('Importing a module script failed.');
  },
}));

describe('IconsProvider', () => {
  it('should still render its children when the icons chunk fails to load', async () => {
    const unhandledRejection = jest.fn();
    process.on('unhandledRejection', unhandledRejection);

    render(
      <IconsProvider>
        <div>children content</div>
      </IconsProvider>,
    );

    expect(screen.getByText('children content')).toBeInTheDocument();

    await waitFor(() => {
      expect(unhandledRejection).not.toHaveBeenCalled();
    });

    process.off('unhandledRejection', unhandledRejection);
  });
});
