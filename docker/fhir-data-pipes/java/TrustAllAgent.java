import java.lang.instrument.Instrumentation;
import javax.net.ssl.HttpsURLConnection;
import javax.net.ssl.SSLContext;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;
import java.security.cert.X509Certificate;

public class TrustAllAgent {
    public static void premain(String agentArgs, Instrumentation inst) {
        try {
            TrustManager[] trustAllCerts = new TrustManager[]{
                new X509TrustManager() {
                    public X509Certificate[] getAcceptedIssuers() { return null; }
                    public void checkClientTrusted(X509Certificate[] certs, String authType) { }
                    public void checkServerTrusted(X509Certificate[] certs, String authType) { }
                }
            };

            SSLContext sc = SSLContext.getInstance("SSL");
            sc.init(null, trustAllCerts, new java.security.SecureRandom());

            // Sets the default for HttpsURLConnection
            HttpsURLConnection.setDefaultSSLSocketFactory(sc.getSocketFactory());

            // Sets the default for most modern HTTP clients (including Apache HttpClient used by HAPI)
            SSLContext.setDefault(sc);

            System.out.println("[AGENT] Global SSL Bypass Activated - All Certificates Trusted.");
        } catch (Exception e) {
            System.err.println("[AGENT] Failed to initialize SSL bypass");
            e.printStackTrace();
        }
    }
}

