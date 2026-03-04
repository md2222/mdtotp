using Gtk;
using Xml;

[DBus (name = "org.freedesktop.timedate1")]
interface TimeDateHandler : Object {
    [DBus (name = "NTP")]
    public abstract bool ntp_enabled { get; }

    [DBus (name = "NTPSynchronized")]
    public abstract bool is_synchronized { get; }
}


const string AppTitle = "MD TOTP";
const string AppName = "mdtotp";

//[Inline]
void debug(string format, ...) {
#if DEBUG
    var va_list = va_list();
    stdout.vprintf("DEBUG:  " + format + "\n", va_list);
    stdout.flush();
#endif
}


// Gtk.MessageType.INFO WARNING ERROR QUESTION
ResponseType MessageBox(Gtk.Window parent, string title, string message,
        Gtk.MessageType type = Gtk.MessageType.WARNING, ButtonsType buttons = ButtonsType.OK)
{
    var dialog = new Gtk.MessageDialog (
        parent,
        Gtk.DialogFlags.MODAL | Gtk.DialogFlags.DESTROY_WITH_PARENT,
        type,
        buttons,
        "%s", message
    );
    
    dialog.set_title (title);

    var content_area = dialog.get_content_area();
    content_area.margin_top = 10;
    content_area.set_border_width(4); 

    ResponseType resp = dialog.run ();
    dialog.destroy ();

    return resp;
}


public class Account : Object
{
    public string id { get; set; }  // string - useful for XML
    public string name { get; set; }
    public string secret { get; set; }
}


public class MainWindow : Window
{

private Gtk.ListStore list_store;
private TreeView tree_view;
private Statusbar statusbar;
private uint status_context_id;
private List<Account> accounts = new List<Account>();
private string passw;  // == null !


public MainWindow()
{
    stdout.printf("%s 0.3.1  3.03.2026\n", AppTitle);
    
    this.title = AppTitle;
    this.set_type_hint(Gdk.WindowTypeHint.DIALOG);
    this.set_default_size(250, 400);
    this.set_position(Gtk.WindowPosition.CENTER);
    this.destroy.connect(Gtk.main_quit);

    var main_vbox = new Box(Orientation.VERTICAL, 0);
    this.add(main_vbox);

    var toolbar = new Toolbar();
    toolbar.get_style_context().add_class(STYLE_CLASS_PRIMARY_TOOLBAR);
    //toolbar.set_icon_size(Gtk.IconSize.LARGE_TOOLBAR);
    toolbar.icon_size = Gtk.IconSize.SMALL_TOOLBAR;

    var add_button = new ToolButton(null, "Add");
    add_button.set_icon_name("document-new");
    add_button.clicked.connect(on_add_clicked);
    toolbar.add(add_button);

    var delete_button = new ToolButton(null, "Delete");
    delete_button.set_icon_name("edit-delete");
    delete_button.clicked.connect(remove_entry);
    toolbar.add(delete_button);

    var passw_button = new ToolButton(null, "Password");
    passw_button.set_icon_name("dialog-password"); 
    passw_button.clicked.connect(on_passw_clicked);
    toolbar.add(passw_button);

    var run_button = new ToolButton(null, "Run");
    run_button.set_icon_name("media-playback-start"); 
    run_button.clicked.connect(on_run_clicked);
    toolbar.add(run_button);

    main_vbox.pack_start(toolbar, false, false, 0);

    list_store = new Gtk.ListStore(1, typeof(string));
    tree_view = new TreeView.with_model(list_store);
    tree_view.set_headers_visible(false); 
    
    var column = new TreeViewColumn();
    var cell = new CellRendererText();
    column.pack_start(cell, true);
    column.add_attribute(cell, "text", 0);
    tree_view.append_column(column);

    var scrolled_window = new ScrolledWindow(null, null);
    scrolled_window.add(tree_view);
    main_vbox.pack_start(scrolled_window, true, true, 0);

    statusbar = new Statusbar();
    status_context_id = statusbar.get_context_id("main");
    statusbar.margin = 2;
    main_vbox.pack_start(statusbar, false, false, 0);

    this.destroy.connect (() => {
        foreach (var acc in accounts)
            Memory.set(acc.secret.data, 0, acc.secret.length);
        accounts = null;
        Gtk.main_quit ();
    });

    Oath.init();

    check_ntp_status();

    Idle.add(() => {
        show_passw_dialog(true);
        return false; 
    });
}


void show_passw_dialog(bool load)
{
    bool ok = false;
    var dialog = new PasswDialog(this);
    
    ResponseType resp = dialog.run();
    string val = dialog.passw;
    dialog.destroy();

    if (resp == ResponseType.OK)
    {
        passw = val;
        if (passw.length > 0)
            ok = true;
    }
    
    if (!ok)
    {
        debug("show_passw_dialog:  not ok");
        if (passw == null || passw.length == 0)
            this.close();
    }
    else if (load && !load_accounts())
        show_passw_dialog(load);
}


void on_passw_clicked()
{
    if (MessageBox(this, AppTitle, "Are you sure you want to change your password?", MessageType.QUESTION, ButtonsType.YES_NO) != ResponseType.YES)
        return;

    show_passw_dialog(false);
    save_accounts();
}


void check_ntp_status()
{
    try
    {
    
    TimeDateHandler timedate = Bus.get_proxy_sync (
        BusType.SYSTEM, 
        "org.freedesktop.timedate1", 
        "/org/freedesktop/timedate1"
    );

    string status = "NTP:  ";
    
    if (timedate.ntp_enabled)
    {
        if (timedate.is_synchronized)
            status += "active";
        else
            status += "active, but synchronizing...";
    }
    else
        status += "disabled. (May cause errors)";

    statusbar.push(status_context_id, status);

    }
    catch (GLib.Error e)
    {
        stderr.printf ("NTP:  D-Bus error:  %s\n", e.message);
        statusbar.push(status_context_id, "NTP:  D-Bus error.  [Not fatal]");
    }
}


private void update_tree_view()
{
    list_store.clear();
    
    foreach (var acc in accounts)
    {
        TreeIter iter;
        list_store.append(out iter);
        list_store.set(iter, 0, acc.name);
    }
}


private bool load_accounts()
{
    string config_dir = Path.build_filename(Environment.get_user_config_dir(), AppName);
    string path = Path.build_filename(config_dir, "accounts.dat");

    if (!FileUtils.test(config_dir, FileTest.EXISTS | FileTest.IS_DIR))
    {
        DirUtils.create_with_parents(config_dir, 0700);
    }
    
    stdout.printf("config_dir=%s\n", config_dir);

    if (!FileUtils.test(path, FileTest.EXISTS))
    {
        stdout.printf("Accounts file not found:  %s\n", path);
        statusbar.push(status_context_id, "Accounts file not found");
        return true;
    }

    try
    {
    
    uint8[] decrypted_data = load_data(path, passw);

    //Xml.Doc* doc = Xml.Parser.parse_file(xml_path);
    var doc = Xml.Parser.read_memory((string)decrypted_data, decrypted_data.length);
    
    if (doc == null) return true;

    Xml.Node* root = doc->get_root_element();
    int count = 0;
    
    if (root != null && root->name == "accounts")
    {
        for (Xml.Node* iter = root->children; iter != null; iter = iter->next)
        {
            if (iter->type == Xml.ElementType.ELEMENT_NODE && iter->name == "account")
            {
                var acc = new Account();
                acc.id = iter->get_prop("id");
                acc.name = iter->get_prop("name");
                acc.secret = iter->get_prop("secret");
                accounts.append(acc);
                count++;
                debug("load_xml_data:  %s  %s  %d", acc.id, acc.name, acc.secret.length);
            }
        }

        update_tree_view();
        statusbar.push(status_context_id, "Loaded: %d".printf(count));
    }
    
    Memory.set(decrypted_data, 0, decrypted_data.length);
    delete doc;
    
    }
    catch (GLib.Error e)
    {
        string text = "Load data error:  %s\n".printf(e.message);
        stderr.printf ("%s\n", text);
        MessageBox(this, AppTitle, text, Gtk.MessageType.ERROR);
        return false;
    }
    
    return true;
}


private void on_add_clicked()
{
    var dialog = new AddEntryDialog(this);
    
    if (dialog.run() == ResponseType.OK)
    {
        string name = dialog.resource_name;
        string secret = dialog.secret_key;
        uint64 now = (uint64)new DateTime.now_local().to_unix() - 1771136000;
        string new_id = @"$now";
        debug("on_add_clicked:  %s  %s  %d", new_id, name,  secret.length);

        var acc = new Account () { id = new_id, name = name, secret = secret };
        accounts.append (acc);

        update_tree_view();
        save_accounts(); 
    }
    
    dialog.destroy();
}


private async void on_run_clicked()
{
    TreeSelection selection = tree_view.get_selection();
    TreeModel model;
    TreeIter iter;

    if (selection.get_selected(out model, out iter))
    {
        TreePath path = model.get_path(iter);
        
        int index = path.get_indices()[0];

        Account acc = accounts.nth_data(index);

        if (acc != null)
        {
            debug("on_run_clicked:  %d  %s", index, acc.name);
            
            statusbar.push(status_context_id, "");
            
            var dialog = new GenerateDialog(this, acc.name, acc.secret);
            dialog.run ();
            dialog.destroy ();
        }
    }
    else
    {
        statusbar.push(status_context_id, "Select account first");
    }
}


private void save_accounts()
{
    try
    {

    string config_dir = Path.build_filename (Environment.get_user_config_dir (), AppName);
    string path = Path.build_filename (config_dir, "accounts.dat");
    
    Xml.Doc* doc = new Xml.Doc ("1.0");
    Xml.Node* root = new Xml.Node (null, "accounts");
    doc->set_root_element (root);
    int count = 0;

    foreach (var acc in accounts)
    {
        Xml.Node* node = new Xml.Node (null, "account");
        node->set_prop ("id", acc.id);
        node->set_prop ("name", acc.name);
        node->set_prop ("secret", acc.secret);
        root->add_child (node);
        count++;
    }

    //doc->save_file (xml_path);
    doc->save_format_file_enc(path, "UTF-8", true);

    string xml_text;
    int size;
    doc->dump_memory(out xml_text, out size);
    save_data(path, passw, xml_text.data);
    
    delete doc;

    //stdout.printf ("Saved\n");
    statusbar.push(status_context_id, "Saved: %d".printf(count));
        
    }
    catch (GLib.Error e)
    {
        string text = "Error saving data:  %s".printf(e.message);
        MessageBox(this, AppTitle, text, Gtk.MessageType.ERROR);
    }
}


private async void remove_entry ()
{
    TreeSelection selection = tree_view.get_selection();
    TreeModel model;
    TreeIter treeIter;

    if (!selection.get_selected(out model, out treeIter))
        return;

    TreePath path = model.get_path(treeIter);
    int index = path.get_indices()[0];
    Account acc = accounts.nth_data(index);

    if (acc == null)
        return;

    if (MessageBox(this, AppTitle, "Remove account %s ?".printf(acc.name), MessageType.QUESTION, ButtonsType.YES_NO) != ResponseType.YES)
        return;

    accounts.remove (acc); 

    update_tree_view();
    save_accounts();
    
    //stdout.printf ("Account %s deleted\n", acc.name);
    string text = "Account %s deleted".printf(acc.name);
    statusbar.push(status_context_id, text);
}


public static int main(string[] args)
{
    Gtk.init(ref args);
    var win = new MainWindow();
    win.show_all();
    Gtk.main();
    return 0;
}
    
}
