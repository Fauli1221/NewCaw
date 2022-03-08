/* Account.vala
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
 * Represents an Profile that uses this library.
 *
 * Account extends Profile to add the
 * properties and methods to allow it to
 * interact with the API provided by the platform.
 */
public class Backend.TwitterLegacy.Account : Backend.Account {

  /**
   * The access secret for this specific Account.
   */
  public string access_secret { get; private set; }

  /**
   * Creates an unauthenticated Account.
   *
   * After construction, it is required to either authenticate the account,
   * using the methods init_authentication and authenticate,
   * or to login with the method login.
   */
  public Account () {
    // Construct the object with server information
    Object (
      // Set server and non-authenticated
      server:        Server.instance,
      authenticated: false
    );

    // Create proxy
    proxy = new Rest.OAuthProxy (server.client_key,
                                 server.client_secret,
                                 server.domain,
                                 false);
  }

  /**
   * Prepares the link to launch the authentication of a new Account.
   *
   * @return The link with the site to authenticate the user.
   *
   * @throws Error Any error occurring while requesting the token.
   */
  public override async string init_authentication () throws Error {
    // Get Client instance and determine used redirect uri
    Client application    = Client.instance;
    string used_redirects = application.redirect_uri != null
                              ? application.redirect_uri
                              : Server.OOB_REDIRECT;

    // Request a oauth token with the proxy
    try {
      yield proxy.request_token_async ("oauth/request_token", used_redirects, null);
    } catch (Error e) {
      throw e;
    }

    // Create authentication url
    return @"$(server.domain)/oauth/authorize?oauth_token=$(proxy.token)";
  }

  /**
   * Authenticates the account with an code.
   *
   * This method should be run after init_authentication and use
   * the code retrieved from the site where the user authenticated himself.
   *
   * After completion, you should save the access token retrieved
   * from the platform so you can use the login method on following runs.
   *
   * @param auth_code The authentication code for the user.
   *
   * @throws Error Any error occurring while requesting the token.
   */
  public override async void authenticate (string auth_code) throws Error {
  }

  /**
   * Creates an Account with existing access token.
   *
   * As OAuth 1.0 requires an additional secret,
   * use login_with_secret instead of this method.
   *
   * @param token The access token for the account.
   *
   * @throws Error Any error occurring while requesting the token.
   */
  public override async void login (string token) throws Error {
    critical ("Access secret not given!");
  }

  /**
   * Creates an Account with existing access token.
   *
   * As OAuth 1.0 requires an additional secret,
   * this method should be used instead of login.
   *
   * @param token The access token for the account.
   * @param secret The secret for the access token.
   *
   * @throws Error Any error occurring while requesting the token.
   */
  public async void login_with_secret (string token, string secret) throws Error {
  }

  /**
   * Sets the Profile data for this Account.
   *
   * @param json A Json.Object retrieved from the API.
   */
  private void set_profile_data (Json.Object json) {
  }

  /**
   * Creates a Rest.ProxyCall to perform an API call.
   */
  internal override Rest.ProxyCall create_call () {
    assert (proxy != null);
    return proxy.new_call ();
  }

  /**
   * The proxy used to authorize the API calls.
   */
  private Rest.OAuthProxy proxy;

}
