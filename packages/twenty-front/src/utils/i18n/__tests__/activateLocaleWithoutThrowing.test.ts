import { activateLocaleWithoutThrowing } from '~/utils/i18n/activateLocaleWithoutThrowing';

jest.mock('~/utils/i18n/dynamicActivate', () => ({
  dynamicActivate: jest.fn(),
}));

const { dynamicActivate } = jest.requireMock('~/utils/i18n/dynamicActivate');

describe('activateLocaleWithoutThrowing', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('should activate the requested locale', async () => {
    await activateLocaleWithoutThrowing('fr-FR');

    expect(dynamicActivate).toHaveBeenCalledWith('fr-FR');
  });

  it('should swallow a failed locale chunk import instead of rejecting', async () => {
    dynamicActivate.mockRejectedValueOnce(
      new Error('Importing a module script failed.'),
    );

    await expect(
      activateLocaleWithoutThrowing('fr-FR'),
    ).resolves.toBeUndefined();
  });
});
