using Gtk;
using OpenSSL;


public void save_data(string path, string password, uint8[] plaintext) throws Error 
{
    uint8 salt[16];
    uint8 iv[16];

    if (OpenSSL.rand_bytes(salt, salt.length) != 1 || OpenSSL.rand_bytes(iv, iv.length) != 1)
        throw new IOError.FAILED("Rand_bytes error.");

    uint8 key[32];
    
    int r = OpenSSL.pbkdf2_hmac (
        password, 
        (int)password.length, 
        salt, 
        16,  
        100000, 
        OpenSSL.EVP.sha256(), 
        32,   
        key
    );

    if (r != 1)
        throw new IOError.FAILED("PBKDF2 error.");

    var ctx = new EVP.CipherContext();
    ctx.encrypt_init(OpenSSL.EVP.aes_256_cbc(), null, key, iv);

    uint8[] ciphertext = new uint8[plaintext.length + 16];
    int len1, len2;
    ctx.encrypt_update(ciphertext, out len1, plaintext);
    ctx.encrypt_final(ciphertext[len1:], out len2);
    ciphertext.length = len1 + len2;

    var file = File.new_for_path(path);
    var output = file.replace(null, false, FileCreateFlags.NONE);
    output.write(salt);
    output.write(iv);
    output.write(ciphertext);
}


public uint8[] load_data(string path, string password) throws Error 
{
    var file = File.new_for_path(path);
    var input = file.read();

    uint8 salt[16];
    uint8 iv[16];
    input.read_all(salt, null);
    input.read_all(iv, null);

    uint8 key[32];
    int r = OpenSSL.pbkdf2_hmac(
        password, 
        (int)password.length, 
        salt, 
        16, 
        100000, 
        OpenSSL.EVP.sha256(),
        32, 
        key
    );

    if (r != 1)
        throw new IOError.FAILED("PBKDF2 error.");

    uint8[] ciphertext = new uint8[4096]; 
    size_t bytes_read;
    input.read_all(ciphertext, out bytes_read);
    ciphertext.length = (int)bytes_read;

    var ctx = new EVP.CipherContext();
    ctx.decrypt_init(OpenSSL.EVP.aes_256_cbc(), null, key, iv);

    uint8[] decrypted = new uint8[ciphertext.length];
    int len1, len2;
    ctx.decrypt_update(decrypted, out len1, ciphertext);
    
    if (ctx.decrypt_final(decrypted[len1:], out len2) <= 0)
        throw new IOError.FAILED("Wrong password or file corrupted.");
    
    decrypted.length = len1 + len2;

    return decrypted;
}
