public with sharing class FeatureFlagUtil {
    // Cache feature flags to avoid repeated SOQL queries
    private static Map<String, Boolean> featureFlagCache;
    
    // Available feature flags - add more flags here as needed
    public static final String FEATURE_RETRY_METADATA_OPERATIONS = 'RetryMetadataOperations';
    public static final String FEATURE_ENHANCED_ERROR_HANDLING = 'EnhancedErrorHandling';
    public static final String FEATURE_ADMIN_NOTIFICATIONS = 'AdminNotifications';
    
    // Initialize the cache
    static {
        featureFlagCache = new Map<String, Boolean>();
    }
    
    /**
     * Check if a feature is enabled
     * @param featureName The API name of the feature to check
     * @return Boolean True if enabled, false otherwise
     */
    public static Boolean isEnabled(String featureName) {
        // Return from cache if available
        if (featureFlagCache.containsKey(featureName)) {
            return featureFlagCache.get(featureName);
        }
        
        // Query the feature flag - updated with namespace
        Boolean isEnabled = false;
        try {
            List<Flowdometer__Feature_Flag__mdt> flags = [
                SELECT DeveloperName, Flowdometer__Is_Enabled__c 
                FROM Flowdometer__Feature_Flag__mdt 
                WHERE DeveloperName = :featureName
                LIMIT 1
            ];
            
            isEnabled = !flags.isEmpty() && flags[0].Flowdometer__Is_Enabled__c;
        } catch (Exception e) {
            // If an error occurs (e.g., metadata type not yet deployed), default to false
            System.debug(LoggingLevel.WARN, 'Error checking feature flag ' + featureName + ': ' + e.getMessage());
            isEnabled = false;
        }
        
        // Cache the result
        featureFlagCache.put(featureName, isEnabled);
        return isEnabled;
    }
    
    /**
     * Clear the cache to force re-query of feature flags
     * Useful when feature flags are updated
     */
    public static void clearCache() {
        featureFlagCache.clear();
    }
} 