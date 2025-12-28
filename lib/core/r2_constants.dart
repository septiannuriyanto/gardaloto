class R2Constants {
  static const String workerUrl =
      'https://gardaloto.septian-nuryanto.workers.dev/upload';

  /// Set to true to use Cloudflare Worker for uploads, false to use Supabase Storage.
  static const bool useWorker = true;
}
