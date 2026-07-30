import { type APP_LOCALES } from 'twenty-shared/translations';
import { captureExceptionWithoutThrowing } from '~/utils/captureExceptionWithoutThrowing';
import { dynamicActivate } from '~/utils/i18n/dynamicActivate';

export const activateLocaleWithoutThrowing = async (
  locale: keyof typeof APP_LOCALES,
) => {
  try {
    await dynamicActivate(locale);
  } catch (error) {
    await captureExceptionWithoutThrowing(error);
  }
};
