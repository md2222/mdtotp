using Gtk;


public class PasswDialog : Dialog
{

private Entry passw_entry;
public string passw { get { return passw_entry.text; } }

public PasswDialog(Window parent)
{
    this.title = "Password";
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

    var label = new Label("Password:");
    label.halign = Align.START;
    passw_entry = new Entry();
    passw_entry.hexpand = true;
    passw_entry.visibility = false;
    passw_entry.activates_default = true;

    grid.attach(label, 0, 0, 1, 1);
    grid.attach(passw_entry, 1, 0, 1, 1);

    content_area.add(grid);

    this.add_button("Cancel", ResponseType.CANCEL);
    var ok_button = this.add_button("OK", ResponseType.OK);
    
    this.set_default_response(ResponseType.OK);

    ok_button.sensitive = false;
    passw_entry.changed.connect(() => { validate(ok_button); });

    this.show_all();

    this.response.connect((id) =>
    {
        if (id == ResponseType.OK)
        {
            if (passw_entry.text.length < 4)
            {
                 MessageBox(this, AppTitle, "Password length must be >= 4", Gtk.MessageType.WARNING);
                 Signal.stop_emission_by_name(this, "response");
            }
        }
    });

    this.destroy.connect (() =>
    {
        debug("PasswDialog:  destroy");
        var buffer = passw_entry.get_buffer();
        //buffer.set_text((uint8[])"0");
        buffer.delete_text(0, -1); 
    });
}

private void validate(Widget ok_button)
{
    ok_button.sensitive = (passw_entry.text.length > 0);
}

}
