using Gtk;

namespace Oath {
    [CCode (cheader_filename = "liboath/oath.h")]
    public extern static int init ();

    [CCode (cheader_filename = "liboath/oath.h")]
    public extern static int base32_decode (
        string @in, 
        size_t inlen, 
        [CCode (array_length = false)] out uint8[] @out, 
        out size_t outlen
    );

    [CCode (cname = "oath_totp_generate", cheader_filename = "liboath/oath.h")]
    public extern static int totp_generate (
        string secret, 
        size_t secret_length, 
        uint64 now, 
        uint time_step_size, 
        uint start_offset, 
        uint digits, 
        [CCode (array_length = false)] char[] output_otp 
    );
}


public class GenerateDialog : Dialog
{

private string secret;
private ProgressBar progress_bar;
private Label label_name;
private Label label_code;
private uint timer_id = 0;
private uchar[] secret_bin;
private size_t secret_len;


public GenerateDialog(Window parent, string name, string key)
{
    this.secret = key;
    this.title = "Current code";
    this.transient_for = parent;
    this.modal = true;
    this.set_default_size(350, -1);

    var content_area = this.get_content_area() as Box;
    content_area.margin = 8;
    content_area.spacing = 4;

    var grid = new Grid();
    grid.column_spacing = 8;
    grid.row_spacing = 10;

    label_name = new Label(name);
    label_name.hexpand = true;
    label_name.halign = Align.START;

    label_code = new Label("");
    label_code.use_markup = true;
    label_code.halign = Align.END;
    label_code.valign = Align.CENTER;

    var copy_icon = new Image.from_icon_name("edit-copy-symbolic", IconSize.BUTTON);
    var copy_btn = new Button();
    copy_btn.set_image(copy_icon);
    copy_btn.relief = ReliefStyle.NONE;
    copy_btn.clicked.connect(() =>
    {
        var cb = Clipboard.get(Gdk.Atom.intern("CLIPBOARD", false));
        cb.set_text(label_code.get_text(), -1);
    });

    progress_bar = new ProgressBar();
    progress_bar.hexpand = true;

    grid.attach(label_name,   0, 0, 1, 1);
    grid.attach(label_code,  1, 0, 1, 1);
    grid.attach(copy_btn,     2, 0, 1, 1);
    grid.attach(progress_bar, 0, 1, 3, 1);

    content_area.add(grid);

    this.show_all();

    int decode_res = Oath.base32_decode(secret, secret.length, out secret_bin, out secret_len);
    this.secret = "0000000000000000";

    if (decode_res != 0)
    {
        label_code.set_text("Decode secret error");
        return;
    }
    
    if (update_otp_logic())
        timer_id = Timeout.add(1000, update_otp_logic);

    this.destroy.connect(() =>
    {
        if (timer_id > 0) {
            Source.remove(timer_id);
            timer_id = 0;
        }
    });
}


~GenerateDialog()
{
    //debug("~GenerateDialog:  ");

    if (secret_bin != null)
    {
        for (int i = 0; i < secret_bin.length; i++)  secret_bin[i] = 0;
        secret_bin = null;
    }
}


private bool update_otp_logic()
{
    uint64 now = (uint64)new DateTime.now_utc().to_unix();
    uint step = 30;

    double remaining = (double)(now % step);
    progress_bar.set_fraction(1.0 - (remaining / (double)step));

    char[] otp_out = new char[7]; 
    int res = Oath.totp_generate((string)secret_bin, secret_len, now, step, 0, 6, otp_out);

    if (res == 0)
    {
        string code = (string)otp_out;
        label_code.set_markup("<span size='150%%' weight='bold' font_family='monospace'>%s</span>".printf(code));
    }
    else
    {
        label_code.set_text("Generate code error");
        return false;
    }
    
    return true;
}
    
}
