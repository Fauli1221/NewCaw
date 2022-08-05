/* PostItem.vala
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
 * Displays the content of one Post.
 */
[GtkTemplate (ui="/uk/co/ibboard/Cawbird/ui/Content/PostItem.ui")]
public class PostItem : Gtk.Widget {

  // UI-Elements of PostItem
  [GtkChild]
  private unowned RepostStatus repost_status;

  /**
   * The post displayed in this widget.
   */
  public Backend.Post post {
    get {
      return displayed_post;
    }
    set {
      displayed_post = value;

      // Check if we have a repost
      bool          has_repost = displayed_post != null && displayed_post.post_type == REPOST;
      Backend.Post? repost     = has_repost ? displayed_post                 : null;
      Backend.Post? main_post  = has_repost ? displayed_post.referenced_post : displayed_post;

      // Check if we have a quote
      bool          has_quote  = main_post != null && main_post.post_type == QUOTE;
      Backend.Post? quote      = has_quote ? main_post.referenced_post : null;

      // Set the repost status
      repost_status.visible = has_repost;
      repost_status.repost  = repost;
    }
  }

  /**
   * Deconstructs PostItem and it's childrens.
   */
  public override void dispose () {
    // Destructs children of PostItem
    repost_status.unparent ();
  }

  /**
   * Stores the displayed repost.
   */
  private Backend.Post? displayed_post = null;

}
