/**
 * Resolves the best display name for a service application.
 *
 * Priority:
 *  1. Value of the first `fields` entry whose fieldName contains "name"
 *     (looked up via fieldId in formData / fieldData).
 *  2. Direct key match in fieldData whose key contains "name"
 *     (current Flutter app stores fieldName as the key).
 *  3. fullName from the user account.
 *  4. userName from the user account.
 *  5. "Unknown User" as the final fallback.
 */
export function getApplicantName(application: {
  fields?: Array<{ fieldId?: string; fieldName?: string }>;
  formData?: Record<string, any>;
  fieldData?: Record<string, any>;
  fullName?: string;
  userName?: string;
}): string {
  try {
    const { fields = [], formData = {}, fieldData = {}, fullName, userName } = application;

    // Step 1: fields array + formData (explicit fieldId → fieldName mapping)
    if (fields.length > 0) {
      const nameField = fields.find(
        (f) => f.fieldName && f.fieldName.toLowerCase().includes('name')
      );
      if (nameField?.fieldId) {
        const val = formData[nameField.fieldId] ?? fieldData[nameField.fieldId];
        if (val && String(val).trim()) return String(val).trim();
      }
    }

    // Step 2: fieldData keyed by human-readable fieldName (current Flutter structure)
    const nameKey = Object.keys(fieldData).find((key) =>
      key.toLowerCase().includes('name')
    );
    if (nameKey && fieldData[nameKey] && String(fieldData[nameKey]).trim()) {
      return String(fieldData[nameKey]).trim();
    }

    // Step 3: account fullName
    if (fullName && fullName.trim()) return fullName.trim();

    // Step 4: account userName
    if (userName && userName.trim()) return userName.trim();

    // Step 5: final fallback
    return 'Unknown User';
  } catch (err) {
    console.error('Error getting applicant name:', err);
    return 'Unknown User';
  }
}
