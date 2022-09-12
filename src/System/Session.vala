/* Session.vala
 *
 * Copyright 2022 Frederick Schenk
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

using GLib;

/**
 * Loads and stores persistent states about accounts, servers and windows.
 */
[SingleInstance]
public class Session : Object {

  /**
   * Internal structure holding information about managed accounts.
   */
  private struct AccountData {

    /**
     * The UUID assigned in the storage.
     */
    string uuid;

    /**
     * The platform the account is on.
     */
    PlatformEnum platform;

    /**
     * The UUID for the server the account is located at.
     *
     * Can be null if the platform has a singular server (e.g. Twitter).
     */
    string? server_uuid;

    /**
     * The username of this account.
     */
    string username;

    /**
     * The object of this account.
     */
    Backend.Account data;

    /**
     * Create a AccountData instance from data loaded of the session file.
     *
     * This functions also loads the token and secret from the storage and
     * creates an authenticated Account object for the data variable.
     */
    public static AccountData? from_data (string       uuid_prop,
                                          PlatformEnum platform_prop,
                                          string?      server_prop,
                                          string       username_prop,
                                          ServerData?  account_server) {
      // Create instance with known values
      var instance         = AccountData ();
      instance.uuid        = uuid_prop;
      instance.platform    = platform_prop;
      instance.server_uuid = server_prop;
      instance.username    = username_prop;
      try {
        // Load token from KeyStorage
        string account_token;
        KeyStorage.retrieve_account_access (instance.uuid, out account_token);
        // Create the account object and login
        switch (instance.platform) {
#if SUPPORT_MASTODON
          case MASTODON:
            var mastodon_server = account_server != null
                                    ? account_server.data as Backend.Mastodon.Server
                                    : null;
            if (mastodon_server != null) {
              instance.data = new Backend.Mastodon.Account (mastodon_server);
            } else {
              warning (@"Could not instance account \"$(instance.username)\": server instance missing!");
              return null;
            }
            break;
#endif
#if SUPPORT_TWITTER
          case TWITTER:
            instance.data = new Backend.Twitter.Account ();
            break;
#endif
          default:
            assert_not_reached ();
        }
        // Log the account in
        instance.data.login (account_token);
        assert (instance.data != null);
        // Resave the keys (as Twitter refreshes the token at each login)
        KeyStorage.store_account_access (instance.data, instance.uuid);
      } catch (Error e) {
        warning (@"Failed to initialized account for \"$(instance.username)\": $(e.message)");
        return null;
      }
      return instance;
    }

    /**
     * Create a AccountData instance from an active Account object.
     *
     * This functions creates the required items, like the uuid, for the object.
     */
    public static AccountData from_object (Backend.Account account, ServerData? server) {
      // Create instance and populate values
      string server_uuid   = server != null ? server.uuid : null;
      var instance         = AccountData ();
      instance.uuid        = Uuid.string_random ();
      instance.platform    = PlatformEnum.get_platform_for_account (account);
      instance.username    = account.username;
      instance.server_uuid = server_uuid;
      instance.data        = account;
      return instance;
    }

    /**
     * Retrieves the uuid for an active Account object.
     */
    public static string? get_uuid (Backend.Account? account) {
      // Check that we have an actual account
      if (account == null) {
        return null;
      }

      // Check the account storage
      string account_uuid = null;
      Session.instance.accounts.foreach ((uuid, data) => {
        if (data.data == account) {
          account_uuid = uuid;
        }
      });

      // Return null when not found
      return account_uuid;
    }

  }

  /**
   * Internal structure holding information about managed server.
   */
  private struct ServerData {

    /**
     * The UUID assigned in the storage.
     */
    string uuid;

    /**
     * The platform the server is on.
     */
    PlatformEnum platform;

    /**
     * The domain of this server.
     */
    string domain;

    /**
     * The object of this server.
     */
    Backend.Server data;

#if SUPPORT_MASTODON
    /**
     * Create a ServerData instance from data loaded of the session file.
     *
     * This functions also loads the token and secret from the storage and
     * creates an authenticated Server object for the data variable.
     */
    public static ServerData? from_data (string uuid_prop, PlatformEnum platform_prop, string domain_prop) {
      // Create instance with known values
      var instance      = ServerData ();
      instance.uuid     = uuid_prop;
      instance.platform = platform_prop;
      instance.domain   = domain_prop;
      try {
        // Load token and secret from KeyStorage
        string server_token, server_secret;
        KeyStorage.retrieve_server_access (instance.uuid, out server_token, out server_secret);
        // Create Server object and store it in data
        instance.data = new Backend.Mastodon.Server (instance.domain, server_token, server_secret);
        assert (instance.data != null);
      } catch (Error e) {
        warning (@"Failed to initialized server for \"$(instance.domain)\": $(e.message)");
        return null;
      }
      return instance;
    }
#endif

    /**
     * Create a ServerData instance from an active Server object.
     *
     * This functions creates the required items, like the uuid, for the object.
     */
    public static ServerData from_object (Backend.Server server) {
      // Create instance and populate values
      var instance      = ServerData ();
      instance.uuid     = Uuid.string_random ();
      instance.platform = PlatformEnum.get_platform_for_server (server);
      instance.domain   = server.domain;
      instance.data     = server;
      return instance;
    }

  }

  /**
   * Internal structure holding information about a window.
   */
  private struct WindowData {

    /**
     * The UUID of the account displayed in the window.
     */
    string? account;

    /**
     * The width of the window.
     */
    int width;

    /**
     * The height of the window.
     */
    int height;

    /**
     * Create a WindowData instance from data loaded of the session file.
     */
    public static WindowData? from_data (string account_prop, int width_prop, int height_prop) {
      var instance     = WindowData ();
      instance.account = account_prop;
      instance.width   = width_prop;
      instance.height  = height_prop;
      return instance;
    }

    /**
     * Create a WindowData instance from an active Server object.
     *
     * This functions creates the required items, like the uuid, for the object.
     */
    public static WindowData? from_object (MainWindow window) {
      // Create instance and populate values
      var instance     = WindowData ();
      instance.account = AccountData.get_uuid (window.account);
      window.get_default_size (out instance.width, out instance.height);

      // Only return WindowData if an account is available
      if (instance.account != null) {
        return instance;
      } else {
        return null;
      }
    }

  }

  /**
   * The instance of this session.
   */
  public static Session instance {
    get {
      if (global_instance == null) {
        critical ("Session needs to be initialized before using it!");
      }
      return global_instance;
    }
  }

  /**
   * The application the session runs in.
   */
  public Gtk.Application application { get; construct; }

  /**
   * Provides a list of the managed accounts.
   */
  public ListModel account_list { get; construct; }

  /**
   * Emitted when an authentication callback was received.
   */
  public signal void auth_callback (string state, string code);

  /**
   * Runs at construction of the instance.
   */
  construct {
#if SUPPORT_TWITTER
    // Initializes the Twitter server.
    init_twitter_server ();
#endif

    // Initializes storage hashmaps
    accounts = new HashTable<string, AccountData?> (str_hash, str_equal);
    servers  = new HashTable<string, ServerData?>  (str_hash, str_equal);

    // Create data dir if not already existing
    var data_dir = Path.build_filename (Environment.get_user_data_dir (),
                                        Config.PROJECT_NAME,
                                        null);
    DirUtils.create_with_parents (data_dir, 0750);
  }

  /**
   * Creates a new instance of the session.
   *
   * @param application The Application this session runs in.
   */
  private Session (Gtk.Application application) {
    Object (
      application:  application,
      account_list: new ListStore (typeof (Backend.Account))
    );
  }

  /**
   * Initializes the session.
   *
   * @param application The Application this session runs in.
   */
  public static void init (Gtk.Application application) {
    global_instance = new Session (application);
  }

  /**
   * Adds an Account to the session.
   *
   * @param account The account to be added.
   */
  public static void add_account (Backend.Account account) {
    // When account is a Mastodon one
    ServerData? account_server = null;
#if SUPPORT_MASTODON
    if (account is Backend.Mastodon.Account) {
      // Find the ServerData for the accounts server
      foreach (ServerData server_data in instance.servers.get_values ()) {
        if (server_data.data == account.server) {
          account_server = server_data;
        }
      }
      if (account_server == null) {
        error ("Could not find UUID of the server for account to add.");
      }
    }
#endif

    // Create a AccountData instance for the account and add it
    var accounts_data = AccountData.from_object (account, account_server);
    instance.accounts [accounts_data.uuid] = accounts_data;
    var account_store = instance.account_list as ListStore;
    account_store.append (account);
  }

  /**
   * Returns all managed accounts.
   *
   * @return An array of all accounts in Session.
   */
  public static Backend.Account[] get_accounts () {
    Backend.Account[] account_array = {};
    foreach (AccountData account_data in instance.accounts.get_values ()) {
      account_array += account_data.data;
    }
    return account_array;
  }

  /**
   * Adds an Server to the session.
   *
   * @param server The server to be added.
   */
  public static void add_server (Backend.Server server) {
    // Create a ServerData instance for the server and add it
    var server_data = ServerData.from_object (server);
    instance.servers [server_data.uuid] = server_data;
  }

  /**
   * Checks if an Server for a domain exits or not.
   *
   * @param domain The domain to check the existence of an server for.
   *
   * @return A Backend.Server if one exists for that domain, otherwise null.
   */
  public static Backend.Server? find_server (string domain) {
    foreach (ServerData server_data in instance.servers.get_values ()) {
      if (server_data.domain == domain) {
        return server_data.data;
      }
    }
    return null;
  }

  /**
   * Loads the data for the session from disk.
   */
  public static async void load_session () {
    // Notify application that we need it running
    instance.application.hold ();

    // Load the data from the session file
    WindowData[] windows     = {};
    Variant      stored_data = instance.load_from_file ();
    if (stored_data != null) {
      instance.unpack_data (stored_data, out windows);
    }

    // Load the account data
    Backend.Account[] accounts = get_accounts ();
    foreach (Backend.Account acc in accounts) {
      try {
        yield acc.load_data ();
      } catch (Error e) {
        warning (@"Failed to load data for a account: $(e.message)");
      }
    }

    // Open the windows
    if (windows.length > 0) {
      foreach (WindowData data in windows) {
        // Retrieve the account for the window
        AccountData? acc = instance.accounts [data.account];
        if (acc != null) {
          // Create a MainWindow for the Account
          var win = new MainWindow (instance.application, acc.data);
          win.set_default_size (data.width, data.height);
          win.present ();
        } else {
          warning ("Account for window not found in session!");
        }
      }
    } else if (accounts.length > 0) {
      // If no window is stored, but we have accounts, use one account for a window
      var win = new MainWindow (instance.application, accounts [0]);
      win.present ();
    } else {
      // Create MainWindow with AuthView
      var win = new MainWindow (instance.application);
      win.present ();
    }

    // Decrease application use count from previous hold
    instance.application.release ();
  }

  /**
   * Stores the data of the session on disk.
   */
  public static void store_session () {
    // Create a Variant and store it
    Variant session_store = instance.pack_data ();
    instance.store_to_file (session_store);
  }

  /**
   * Unpacks the loaded Variant and stores the contained information.
   *
   * @param loaded_data The variant loaded and to be unpacked.
   * @param windows An array where the WindowData is unpacked to.
   */
  private void unpack_data (Variant loaded_data, out WindowData[] windows) {
#if SUPPORT_MASTODON
    // Iterate through the servers
    Variant     loaded_servers  = loaded_data.lookup_value ("Servers", null);
    VariantIter server_iter     = loaded_servers.iterator ();
    while (true) {
      Variant? iter_variant = server_iter.next_value ();
      if (iter_variant == null) {
        break;
      }

      // Get the server dictionary
      Variant server = iter_variant.get_child_value (0);

      // Load the server properties
      string? uuid_prop;
      string? platform_name;
      string? domain_prop;
      server.lookup ("uuid",     "s", out uuid_prop);
      server.lookup ("platform", "s", out platform_name);
      server.lookup ("domain",   "s", out domain_prop);

      // Create a new ServerData instance when all properties could be retrieved
      if (uuid_prop != null && platform_name != null && domain_prop != null) {
        var platform_prop = PlatformEnum.from_name (platform_name);
        var server_data   = ServerData.from_data (uuid_prop, platform_prop, domain_prop);
        if (server_data != null) {
          servers [server_data.uuid] = server_data;
        }
      } else {
        warning ("A server could not be loaded: Some data were missing!");
      }
    }
#endif

    // Iterate through the accounts
    Variant     loaded_accounts = loaded_data.lookup_value ("Accounts", null);
    VariantIter account_iter    = loaded_accounts.iterator ();
    while (true) {
      Variant? iter_variant = account_iter.next_value ();
      if (iter_variant == null) {
        break;
      }

      // Get the account dictionary
      Variant account = iter_variant.get_child_value (0);

      // Load the account properties
      string? uuid_prop;
      string? platform_name;
      string? server_prop;
      string? username_prop;
      account.lookup ("uuid",        "ms", out uuid_prop);
      account.lookup ("platform",    "ms", out platform_name);
      account.lookup ("server_uuid", "ms", out server_prop);
      account.lookup ("username",    "ms", out username_prop);

      // Create a new AccountData instance when all properties could be retrieved
      if (uuid_prop != null && platform_name != null && username_prop != null) {
        var platform_prop = PlatformEnum.from_name (platform_name);
        ServerData? account_server = server_prop != null ? servers [server_prop] : null;
        var account_data = AccountData.from_data (uuid_prop, platform_prop, server_prop, username_prop, account_server);
        if (account_data != null) {
          accounts [account_data.uuid] = account_data;
          var account_store = instance.account_list as ListStore;
          account_store.append (account_data.data);
        }
      } else {
        warning ("A account could not be loaded: Some data were missing!");
      }
    }

    // Iterate through the windows
    WindowData[] packed_windows = {};
    Variant      loaded_windows = loaded_data.lookup_value ("Windows", null);
    VariantIter  window_iter    = loaded_windows.iterator ();
    while (true) {
      Variant? iter_variant = window_iter.next_value ();
      if (iter_variant == null) {
        break;
      }

      // Get the account dictionary
      Variant window = iter_variant.get_child_value (0);

      // Load the account properties
      Variant? account_variant = window.lookup_value ("account", new VariantType ("s"));
      Variant? width_variant   = window.lookup_value ("width",   new VariantType ("i"));
      Variant? height_variant  = window.lookup_value ("height",  new VariantType ("i"));

      // Create a new AccountData instance when all properties could be retrieved
      if (account_variant != null && width_variant != null && height_variant != null) {
        string account_prop = account_variant.get_string ();
        int    width_prop   = width_variant.get_int32 ();
        int    height_prop  = height_variant.get_int32 ();
        var    window_data  = WindowData.from_data (account_prop, width_prop, height_prop);
        if (window_data != null) {
          packed_windows += window_data;
        }
      } else {
        warning ("A window could not be loaded: Some data were missing!");
      }
    }

    // Return the unpacked WindowData over the out parameter
    windows = packed_windows;
  }

  /**
   * Packs managed accounts and servers into a Variant to be stored.
   *
   * @return A Variant holding the information to be stored.
   */
  private Variant pack_data () {
    var store_builder = new VariantBuilder (new VariantType ("a{sv}"));

#if SUPPORT_MASTODON
    // Build Variant for ServerData
    var server_builder = new VariantBuilder (new VariantType ("av"));
    foreach (ServerData server_data in servers.get_values ()) {
      // Save access tokens for the server
      try {
        KeyStorage.store_server_access (server_data.data, server_data.uuid);
      } catch (Error e) {
        warning (@"Could not save access tokens for Server \"$(server_data.domain)\": $(e.message)");
      }

      // Store data in a dictionary Variant
      var data_builder = new VariantBuilder (new VariantType ("a{ss}"));
      data_builder.add ("{ss}", "uuid",     server_data.uuid);
      data_builder.add ("{ss}", "platform", server_data.platform.to_string ());
      data_builder.add ("{ss}", "domain",   server_data.domain);

      server_builder.add ("v", data_builder.end ());
    }
    store_builder.add ("{sv}", "Servers",  server_builder.end ());
#endif

    // Build Variant for AccountData
    var account_builder = new VariantBuilder (new VariantType ("av"));
    foreach (AccountData account_data in accounts.get_values ()) {
      // Save access tokens for the server
      try {
        KeyStorage.store_account_access (account_data.data, account_data.uuid);
      } catch (Error e) {
        warning (@"Could not save access tokens for Account \"$(account_data.username)\": $(e.message)");
      }

      // Store data in a dictionary Variant
      var data_builder = new VariantBuilder (new VariantType ("a{sms}"));
      data_builder.add ("{sms}", "uuid",        account_data.uuid);
      data_builder.add ("{sms}", "platform",    account_data.platform.to_string ());
      data_builder.add ("{sms}", "server_uuid", account_data.server_uuid);
      data_builder.add ("{sms}", "username",    account_data.username);

      account_builder.add ("v", data_builder.end ());
    }
    store_builder.add ("{sv}", "Accounts", account_builder.end ());

    // Build Variant for WindowData
    var window_builder = new VariantBuilder (new VariantType ("av"));
    foreach (Gtk.Window window in instance.application.get_windows ()) {
      // Only store MainWindows
      var main = window as MainWindow;
      if (main == null) {
        continue;
      }

      // Create a data object
      var window_data = WindowData.from_object (main);
      // Only store WindowData if it has an valid account uuid
      if (window_data == null) {
        continue;
      }

      // Store data in a dictionary Variant
      var data_builder = new VariantBuilder (new VariantType ("a{sv}"));
      data_builder.add ("{sv}", "account", new Variant.string (window_data.account));
      data_builder.add ("{sv}", "width",   new Variant.int32 (window_data.width));
      data_builder.add ("{sv}", "height",  new Variant.int32 (window_data.height));

      window_builder.add ("v", data_builder.end ());
    }
    store_builder.add ("{sv}", "Windows", window_builder.end ());

    // Return the full session variant
    return store_builder.end ();
  }

  /**
   * Loads the data stored in the session file.
   *
   * @return A Variant holding the data from the file.
   */
  private Variant? load_from_file () {
    // Initializes the file storing the session
    var file = File.new_build_filename (Environment.get_user_data_dir (),
                                        Config.PROJECT_NAME,
                                        "session.gvariant",
                                        null);

    Variant? stored_session;
    try {
      // Load the data from the file
      uint8[] file_content;
      string file_etag;
      file.load_contents (null, out file_content, out file_etag);
      // Convert the file data to an Variant and read the values from it
      var stored_bytes = new Bytes.take (file_content);
      stored_session   = new Variant.from_bytes (new VariantType ("a{sv}"), stored_bytes, false);
    } catch (Error e) {
      // Don't put warning out if the file can't be found (expected error)
      if (! (e is IOError.NOT_FOUND)) {
        error (@"Session file could not be loaded properly: $(e.message)");
      }
      stored_session = null;
    }
    return stored_session;
  }

  /**
   * Stores the session data in the session file.
   *
   * @param variant The Variant holding the session data.
   */
  private void store_to_file (Variant variant) {
    // Initializes the file storing the session
    var file = File.new_build_filename (Environment.get_user_data_dir (),
                                        Config.PROJECT_NAME,
                                        "session.gvariant",
                                        null);

    try {
      // Convert variant to Bytes and store them in file
      Bytes bytes = variant.get_data_as_bytes ();
      file.replace_contents (bytes.get_data (), null,
                             false, REPLACE_DESTINATION,
                             null, null);
    } catch (Error e) {
      warning (@"Session could not be stored: $(e.message)");
    }
  }

#if SUPPORT_TWITTER
  /**
   * Initializes the Server instance for the Twitter backend.
   */
  private void init_twitter_server () {
    // Look for override tokens
    var    settings   = new Settings ("uk.co.ibboard.Cawbird.debug");
    string custom_key = settings.get_string ("twitter-oauth-key");

    // Determine oauth tokens
    string oauth_key = custom_key != ""
                         ? custom_key
                         : Config.TWITTER_OAUTH_KEY;

    // Initializes the server
    new Backend.Twitter.Server (oauth_key);
  }
#endif

  /**
   * Stores the global instance of this session.
   */
  private static Session? global_instance = null;

  /**
   * Stores accounts managed by the Session class.
   */
  private HashTable<string, AccountData?> accounts;

  /**
   * Stores servers managed by the Session class.
   */
  private HashTable<string, ServerData?> servers;

}
