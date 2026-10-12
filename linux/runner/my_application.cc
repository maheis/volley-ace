#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#include <gio/gdesktopappinfo.h>
#include <cstring>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication
{
  GtkApplication parent_instance;
  char **dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static gchar *escape_desktop_exec(const gchar *value)
{
  GString *escaped = g_string_new("\"");
  for (const gchar *character = value; *character != '\0'; character++)
  {
    if (*character == '\\' || *character == '"' || *character == '%')
    {
      g_string_append_c(escaped, '\\');
    }
    g_string_append_c(escaped, *character);
  }
  g_string_append_c(escaped, '"');
  return g_string_free(escaped, FALSE);
}

static gboolean write_file_if_changed(const gchar *path,
                                      const gchar *contents,
                                      GError **error)
{
  g_autofree gchar *current = nullptr;
  gsize current_length = 0;
  if (g_file_get_contents(path, &current, &current_length, nullptr) &&
      current_length == std::strlen(contents) &&
      g_strcmp0(current, contents) == 0)
  {
    return FALSE;
  }
  return g_file_set_contents(path, contents, -1, error);
}

static void update_desktop_database(const gchar *program, const gchar *path)
{
  gchar *arguments[] = {
      const_cast<gchar *>(program),
      const_cast<gchar *>(path),
      nullptr,
  };
  g_autoptr(GError) error = nullptr;
  if (!g_spawn_sync(nullptr, arguments, nullptr, G_SPAWN_SEARCH_PATH, nullptr,
                    nullptr, nullptr, nullptr, nullptr, &error))
  {
    g_debug("Unable to run %s: %s", program, error->message);
  }
}

static void register_vace_file_handler(void)
{
  g_autofree gchar *executable_path =
      g_file_read_link("/proc/self/exe", nullptr);
  if (executable_path == nullptr)
  {
    return;
  }

  const gchar *data_directory = g_get_user_data_dir();
  g_autofree gchar *applications_directory =
      g_build_filename(data_directory, "applications", nullptr);
  g_autofree gchar *mime_packages_directory =
      g_build_filename(data_directory, "mime", "packages", nullptr);
  if (g_mkdir_with_parents(applications_directory, 0755) != 0 ||
      g_mkdir_with_parents(mime_packages_directory, 0755) != 0)
  {
    g_warning("Unable to create user desktop file-association directories.");
    return;
  }

  g_autofree gchar *desktop_path = g_build_filename(
      applications_directory, "volleyace-vace.desktop", nullptr);
  g_autofree gchar *mime_path = g_build_filename(
      mime_packages_directory, "volleyace-vace.xml", nullptr);
  g_autofree gchar *escaped_executable =
      escape_desktop_exec(executable_path);
  g_autofree gchar *desktop_entry = g_strdup_printf(
      "[Desktop Entry]\n"
      "Type=Application\n"
      "Name=Volley Ace\n"
      "Comment=Volleyball Assistenz-App\n"
      "Exec=%s %%f\n"
      "TryExec=%s\n"
      "Terminal=false\n"
      "Categories=Utility;Education;\n"
      "MimeType=application/vnd.volleyace;\n",
      escaped_executable, executable_path);
  const gchar *mime_definition =
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
      "<mime-info xmlns=\"http://www.freedesktop.org/standards/shared-mime-info\">\n"
      "  <mime-type type=\"application/vnd.volleyace\">\n"
      "    <comment>Volley Ace backup</comment>\n"
      "    <glob pattern=\"*.vace\"/>\n"
      "  </mime-type>\n"
      "</mime-info>\n";

  gboolean applications_changed = FALSE;
  gboolean mime_changed = FALSE;
  g_autoptr(GError) error = nullptr;
  applications_changed = write_file_if_changed(
      desktop_path, desktop_entry, &error);
  if (error != nullptr)
  {
    g_warning("Unable to register Volley Ace desktop entry: %s",
              error->message);
    return;
  }
  mime_changed = write_file_if_changed(mime_path, mime_definition, &error);
  if (error != nullptr)
  {
    g_warning("Unable to register Volley Ace MIME type: %s", error->message);
    return;
  }

  if (applications_changed)
  {
    update_desktop_database("update-desktop-database",
                            applications_directory);
  }
  if (mime_changed)
  {
    g_autofree gchar *mime_directory =
        g_build_filename(data_directory, "mime", nullptr);
    update_desktop_database("update-mime-database", mime_directory);
  }

  g_autoptr(GAppInfo) default_application =
      g_app_info_get_default_for_type("application/vnd.volleyace", FALSE);
  if (default_application == nullptr)
  {
    g_autoptr(GDesktopAppInfo) desktop_info =
        g_desktop_app_info_new_from_filename(desktop_path);
    if (desktop_info != nullptr &&
        !g_app_info_set_as_default_for_type(
            G_APP_INFO(desktop_info), "application/vnd.volleyace", &error) &&
        error != nullptr)
    {
      g_debug("Unable to set Volley Ace as the default .vace handler: %s",
              error->message);
    }
  }
}

static void set_window_icon(GtkWindow *window)
{
  const gchar *relative_path =
      "data/flutter_assets/assets/icons/color_transparent_icon.png";
  g_autofree gchar *executable_path = g_file_read_link("/proc/self/exe", nullptr);
  g_autofree gchar *executable_dir = executable_path == nullptr
                                         ? nullptr
                                         : g_path_get_dirname(executable_path);
  g_autofree gchar *bundled_path = executable_dir == nullptr
                                       ? nullptr
                                       : g_build_filename(
                                             executable_dir, relative_path,
                                             nullptr);
  const gchar *paths[] = {
      bundled_path,
      relative_path,
      "assets/icons/color_transparent_icon.png",
  };

  for (const gchar *path : paths)
  {
    if (path == nullptr || !g_file_test(path, G_FILE_TEST_IS_REGULAR))
    {
      continue;
    }
    g_autoptr(GError) error = nullptr;
    if (gtk_window_set_icon_from_file(window, path, &error))
    {
      return;
    }
    g_warning("Failed to load application icon from %s: %s", path,
              error->message);
  }
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication *self, FlView *view)
{
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication *application)
{
  MyApplication *self = MY_APPLICATION(application);
  GtkWindow *window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  set_window_icon(window);

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen *screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen))
  {
    const gchar *wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0)
    {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar)
  {
    GtkHeaderBar *header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "Volley Ace");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  }
  else
  {
    gtk_window_set_title(window, "Volley Ace");
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView *view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication *application,
                                                  gchar ***arguments,
                                                  int *exit_status)
{
  MyApplication *self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error))
  {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication *application)
{
  register_vace_file_handler();

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication *application)
{
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject *object)
{
  MyApplication *self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass *klass)
{
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication *self) {}

MyApplication *my_application_new()
{
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
