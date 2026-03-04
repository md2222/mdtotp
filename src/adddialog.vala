using Gtk;


public class AddEntryDialog : Dialog
{
private Entry account_entry;
private Entry secret_entry;

public string resource_name { get { return account_entry.text; } }
public string secret_key { get { return secret_entry.text; } }


public AddEntryDialog(Window parent)
{
    this.title = "Add account";
    this.transient_for = parent;
    this.modal = true;
    this.set_default_size(300, -1);
    this.resizable = false;

    var action_area = this.get_action_area() as Gtk.Box;
    action_area.border_width = 0;

    var content_area = this.get_content_area() as Box;
    content_area.margin = 10;
    content_area.margin_top = 15;
    content_area.spacing = 18;

    var grid = new Grid();
    grid.column_spacing = 10;
    grid.row_spacing = 8;

    var label_res = new Label("Account:");
    label_res.halign = Align.START;
    account_entry = new Entry();
    account_entry.hexpand = true;

    var label_sec = new Label("Secret:");
    label_sec.halign = Align.START;
    secret_entry = new Entry();
    secret_entry.hexpand = true;
    secret_entry.activates_default = true;

    grid.attach(label_res, 0, 0, 1, 1);
    grid.attach(account_entry, 1, 0, 1, 1);
    grid.attach(label_sec, 0, 1, 1, 1);
    grid.attach(secret_entry, 1, 1, 1, 1);

    content_area.add(grid);

    this.add_button("Cancel", ResponseType.CANCEL);
    var ok_button = this.add_button("OK", ResponseType.OK);
    
    this.set_default_response(ResponseType.OK);

    ok_button.sensitive = false;
    account_entry.changed.connect(() => { validate(ok_button); });
    secret_entry.changed.connect(() => { validate(ok_button); });

    this.show_all();
}

private void validate(Widget ok_button)
{
    ok_button.sensitive = (account_entry.text.length > 0 && secret_entry.text.length > 0);
}

}
