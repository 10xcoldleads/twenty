export const captureExceptionWithoutThrowing = async (error: unknown) => {
  try {
    const { captureException } = await import('@sentry/react');
    captureException(error);
  } catch {
    return;
  }
};
