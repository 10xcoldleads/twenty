import { activateLocaleWithoutThrowing } from '~/utils/i18n/activateLocaleWithoutThrowing';

jest.mock('~/utils/i18n/dynamicActivate', () => ({
  dynamicActivate: jest.fn(),
}));

jest.mock('~/utils/captureExceptionWithoutThrowing', () => ({
  captureExceptionWithoutThrowing: jest.fn(),
}));

const { dynamicActivate } = jest.requireMock('~/utils/i18n/dynamicActivate');
const { captureExceptionWithoutThrowing } = jest.requireMock(
  '~/utils/captureExceptionWithoutThrowing',
);

describe('activateLocaleWithoutThrowing', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('should activate the requested locale', async () => {
    await activateLocaleWithoutThrowing('fr-FR');

    expect(dynamicActivate).toHaveBeenCalledWith('fr-FR');
    expect(captureExceptionWithoutThrowing).not.toHaveBeenCalled();
  });

  it('should report a failed locale chunk import instead of rejecting', async () => {
    const error = new Error('Importing a module script failed.');
    dynamicActivate.mockRejectedValueOnce(error);

    await expect(
      activateLocaleWithoutThrowing('fr-FR'),
    ).resolves.toBeUndefined();

    expect(captureExceptionWithoutThrowing).toHaveBeenCalledWith(error);
  });
});
