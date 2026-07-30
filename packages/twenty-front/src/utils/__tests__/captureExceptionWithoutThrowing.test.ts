import { captureExceptionWithoutThrowing } from '~/utils/captureExceptionWithoutThrowing';

jest.mock('@sentry/react', () => ({
  captureException: jest.fn(),
}));

const { captureException } = jest.requireMock('@sentry/react');

describe('captureExceptionWithoutThrowing', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('should report the error to Sentry', async () => {
    const error = new Error('Importing a module script failed.');

    await captureExceptionWithoutThrowing(error);

    expect(captureException).toHaveBeenCalledWith(error);
  });

  it('should resolve when the Sentry capture itself fails', async () => {
    captureException.mockImplementationOnce(() => {
      throw new Error('Sentry is unavailable');
    });

    await expect(
      captureExceptionWithoutThrowing(new Error('boom')),
    ).resolves.toBeUndefined();
  });
});
