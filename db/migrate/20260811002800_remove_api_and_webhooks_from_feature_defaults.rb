class RemoveApiAndWebhooksFromFeatureDefaults < ActiveRecord::Migration[7.1]
  def up
    # The api_and_webhooks flag no longer exists in config/features.yml.
    # Its stale entry in ACCOUNT_LEVEL_FEATURE_DEFAULTS causes a NoMethodError
    # (feature_api_and_webhooks= undefined) every time a new Account is created,
    # because enable_default_features blindly calls send("feature_#{name}=")
    # for every entry in that config record.
    #
    # ConfigLoader only adds new flags; it never removes renamed/deleted ones,
    # so this migration handles the one-time cleanup -- following the same
    # pattern used in 20260324102005_repurpose_response_bot_flag_for_custom_tools.rb.
    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    return if config&.value.blank?

    config.value = config.value.reject { |f| f['name'] == 'api_and_webhooks' }
    config.save!
    GlobalConfig.clear_cache
  end

  def down
    # Restore the entry in case of rollback (disabled by default, as it was never a
    # valid feature in this fork).
    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    return if config.blank?
    return if config.value.any? { |f| f['name'] == 'api_and_webhooks' }

    config.value = config.value + [{ 'name' => 'api_and_webhooks', 'enabled' => false }]
    config.save!
    GlobalConfig.clear_cache
  end
end
