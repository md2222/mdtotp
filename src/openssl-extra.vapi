[CCode (cprefix = "", lower_case_cprefix = "")]
namespace OpenSSL
{
    [CCode (cname = "RAND_bytes", cheader_filename = "openssl/rand.h")]
    public static int rand_bytes ([CCode (array_length = false)] uint8[] buf, int num);

    [CCode (cname = "PKCS5_PBKDF2_HMAC", cheader_filename = "openssl/evp.h")]
    public static int pbkdf2_hmac (
        string pass, 
        int passlen, 
        [CCode (array_length = false)] uint8[] salt, // No length
        int saltlen, 
        int iter, 
        EVP.MessageDigest digest, 
        int keylen, 
        [CCode (array_length = false)] uint8[] out_key // No length
    );
}
