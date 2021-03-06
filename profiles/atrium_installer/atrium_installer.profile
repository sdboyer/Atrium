<?php
// $Id$

/**
 * Implementation of hook_profile_details().
 */
function atrium_installer_profile_details() {
  return array(
    'name' => 'Atrium',
    'description' => 'Atrium by Development Seed.'
  );
}

/**
 * Implementation of hook_profile_modules().
 */
function atrium_installer_profile_modules() {
  // Drupal core
  $modules = array(
    'block',
    'comment',
    'dblog',
    'filter',
    'help',
    'menu',
    'node',
    'openid',
    'search',
    'system', 
    'taxonomy',
    'trigger',
    'upload',
    'user',
  );
  return $modules;
}

/**
 * Returns an array list of core atrium modules.
 */
function _atrium_installer_core_modules() {
  return array(
    // Admin
    'admin',
    // Views
    'views', 'views_ui', 'litenode',
    // OG
    'og', 'og_access', 'og_actions', 'og_views',
    // Context
    'context', 'context_contrib', 'context_ui',
    // Features
    'features',
    // Image
    'imageapi', 'imageapi_gd', 'imagecache', 'imagecache_ui',
    // Token
    'token',
    // Transliteration
    'transliteration',
    // Messaging
    'messaging', 'messaging_mail',
    // Notifications
    'notifications', 'notifications_content',
    // Open ID
    'openidadmin',
    // PURL
    'purl',
    // Seed
    'seed',
    // Spaces
    'spaces', 'spaces_site', 'spaces_user', 'spaces_og',
    // Ucreate
    'ucreate', 'ucreate_og',
    // Atrium
    'atrium',
  );
}

/**
 * Returns an array list of dsi modules.
 */
function _atrium_installer_atrium_modules() {
  return array(
    // Strongarm
    'strongarm',
    // Core features
    'book',
    // Admin message
    'admin_message',
    // Casetracker
    'casetracker', 'casetracker_basic',
    // Calendar, date
    'date', 'date_api', 'date_popup', 'litecal',
    // CCK
    'content', 'nodereference', 'text', 'optionwidgets',
    // FeedAPI
    'feedapi', 'feedapi_node', 'feedapi_mapper', 'feedapi_inherit', 'parser_ical',
    // Flot
    'flot',
    // Messaging
    'messaging_shoutbox',
    // Notifications
    'notifications_team', 'mail2web', 'mailhandler',
    // Content profile
    'content_profile',
    // Atrium features
    'atrium_blog', 'atrium_book', 'atrium_calendar', 'atrium_dashboard', 'atrium_casetracker', 'atrium_profile', 'atrium_shoutbox',
    // Formats
    'codefilter', 'markdown',
    // Others
    'comment_upload', 'diff', 'prepopulate', 'xref',
    // Spaces design customizer
    'color', 'spaces_design',
    // VBO
    'views_bulk_operations',
    // Atrium intranet distro module
    'atrium_intranet',
  );
}

/**
 * Implementation of hook_profile_task_list().
 */
function atrium_installer_profile_task_list() {
  $tasks = array(
    'locale-extended-import' => st('Import more translations'),
    'intranet-configure' => st('Intranet configuration'),
  );
  return $tasks;
}

/**
 * Implementation of hook_profile_tasks().
 */
function atrium_installer_profile_tasks(&$task, $url) {
  global $install_locale;
  
  // Just in case some of the future tasks adds some output
  $output = '';

  // Install some more modules and maybe localization helpers too
  if ($task == 'profile') {
    $modules = _atrium_installer_core_modules();
    $modules = array_merge($modules, _atrium_installer_atrium_modules());
    // If not English, install core_translation module.
    if (!empty($install_locale) && ($install_locale != 'en')) {
      $modules[] = 'core_translation';
    }
    $files = module_rebuild_cache();
    $operations = array();
    foreach ($modules as $module) {
      $operations[] = array('_install_module_batch', array($module, $files[$module]->info['name']));
    }
    $batch = array(
      'operations' => $operations,
      'finished' => '_atrium_installer_profile_batch_finished',
      'title' => st('Installing @drupal', array('@drupal' => drupal_install_profile_name())),
      'error_message' => st('The installation has encountered an error.'),
    );
    // Start a batch, switch to 'profile-install-batch' task. We need to
    // set the variable here, because batch_process() redirects.
    variable_set('install_task', 'profile-install-batch');
    batch_set($batch);
    batch_process($url, $url);
  }

  // Import extended interface translations for all the enabled modules.
  // Our translations are in sites/all/translations, these are imported by core_translation module
  if ($task == 'locale-extended-import') {
    if (!empty($install_locale) && ($install_locale != 'en')) {        
      // @todo: Disable English
      // @todo: Check content type/s translation options
      include_once 'includes/locale.inc';
      module_load_include('inc', 'core_translation');

      $batch = core_translation_batch_by_language($install_locale, '_atrium_installer_locale_batch_finished');
      if (!empty($batch)) {
        // Remove temporary variable.
        variable_del('install_locale_batch_components');
        // Start a batch, switch to 'locale-batch' task. We need to
        // set the variable here, because batch_process() redirects.
        variable_set('install_task', 'locale-remaining-batch');
        batch_set($batch);
        batch_process($url, $url);
      }
    }
    // Found nothing to import or not foreign language, go to next task.
    $task = 'intranet-configure';
  }

  // Run additional configuration tasks
  // @todo Review all the cache/rebuild options at the end, some of them may not be needed
  // @todo Review for localization, the time zone cannot be set that way either
  if ($task == 'intranet-configure') {
    // Disable the english locale if using a different default locale.
    if (!empty($install_locale) && ($install_locale != 'en')) {
      db_query("DELETE FROM {languages} WHERE language = 'en'");
    }

    // Remove default input filter formats
    $result = db_query("SELECT * FROM {filter_formats} WHERE name IN ('%s', '%s')", 'Filtered HTML', 'Full HTML');
    while ($row = db_fetch_object($result)) {
      db_query("DELETE FROM {filter_formats} WHERE format = %d", $row->format);
      db_query("DELETE FROM {filters} WHERE format = %d", $row->format);
    }

    // Eliminate the access content perm from anonymous users.
    db_query("UPDATE permission set perm = '' WHERE rid = 1");

    // Create user picture directory
    $picture_path = file_create_path(variable_get('user_picture_path', 'pictures'));
    file_check_directory($picture_path, 1, 'user_picture_path');

    // Create freetagging vocab
    $vocab = array(
      'name' => 'Keywords',
      'multiple' => 0,
      'required' => 0,
      'hierarchy' => 0,
      'relations' => 0,
      'module' => 'event',
      'weight' => 0,
      'nodes' => array('blog' => 1, 'book' => 1),
      'tags' => TRUE,
      'help' => t('Enter tags related to your post.'),
    );
    taxonomy_save_vocabulary($vocab);

    // Set time zone
    variable_set('date_default_timezone_name', 'US/Eastern');

    // Calculate time zone offset from time zone name and set the default timezone offset accordingly.
    // You dont need to change the next two lines if you change the default time zone above.
    $date = date_make_date('now', variable_get('date_default_timezone_name', 'US/Eastern'));
    variable_set('date_default_timezone', date_offset_get($date));

    // Set a default footer message.
    variable_set('site_footer', '&copy; 2009 '. l('Development Seed', 'http://www.developmentseed.org', array('absolute' => TRUE)));

    // Theme
    // @TODO: this actually does not work -- by the time we get here
    // the _system_theme_data() static cache has been populated.
    // We rebuild system_theme_data() on the welcome callback (default frontpage)
    // so this works on the first page load.
    system_theme_data();
    db_query("UPDATE {system} SET status = 0 WHERE type = 'theme' and name ='%s'", 'garland');
    variable_set('theme_default', 'ginkgo');

    // Rebuild key tables/caches
    menu_rebuild();
    module_rebuild_cache(); // Detects the newly added bootstrap modules
    node_access_rebuild();
    drupal_get_schema('system', TRUE); // Clear schema DB cache
    drupal_flush_all_caches();
    db_query("UPDATE {blocks} SET status = 0, region = ''"); // disable all DB blocks

    // Revert the filter that messaging provides to our default.  
    $component = 'filter';
    $module = 'atrium_intranet';
    module_load_include('inc', 'features', "features.{$component}");
    module_invoke($component, 'features_revert', $module);

    // Get out of this batch and let the installer continue
    $task = 'profile-finished';
  }
  return $output;
}

/**
 * Finished callback for the modules install batch.
 *
 * Advance installer task to language import.
 */
function _atrium_installer_profile_batch_finished($success, $results) {
  variable_set('install_task', 'locale-extended-import');
}
/**
 * Finished callback for the first locale import batch.
 *
 * Advance installer task to the configure screen.
 */
function _atrium_installer_locale_batch_finished($success, $results) {
  include_once 'includes/locale.inc';
  _locale_batch_language_finished($success, $results);
  variable_set('install_task', 'intranet-configure');
}
