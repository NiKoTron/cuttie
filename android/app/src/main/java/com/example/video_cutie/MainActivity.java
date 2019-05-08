package com.example.video_cutie;

import android.Manifest;
import android.annotation.SuppressLint;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.media.MediaCodec;
import android.media.MediaExtractor;
import android.media.MediaFormat;
import android.media.MediaMetadataRetriever;
import android.media.MediaMuxer;
import android.media.ThumbnailUtils;
import android.net.Uri;
import android.os.Bundle;
import android.provider.MediaStore;
import android.util.Log;
import android.util.SparseIntArray;

import androidx.core.content.FileProvider;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.channels.FileChannel;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import java.util.regex.Pattern;

import io.flutter.app.FlutterActivity;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;
import nl.bravobit.ffmpeg.ExecuteBinaryResponseHandler;
import nl.bravobit.ffmpeg.FFmpeg;

@SuppressLint("NewApi")
public class MainActivity extends FlutterActivity {
    private static final String TAG = "FlutterActivity";
    private static final int DEFAULT_BUFFER_SIZE = 1 * 1024 * 1024;
  private static final String CHANNEL = "com.video_cutie/trim";
    private static final int READ_REQUEST = 42;
    private Map<String, Object> mTempArgs;
    private MethodChannel.Result mTempResult;

    @Override
  protected void onCreate(Bundle savedInstanceState) {
      super.onCreate(savedInstanceState);
      GeneratedPluginRegistrant.registerWith(this);

      new MethodChannel(getFlutterView(), CHANNEL).setMethodCallHandler(
              (call, result) -> {
                  Map<String, Object> arguments = call.arguments();
                  switch (call.method) {
                      case "trim": {
                          String pathSrc = (String) arguments.get("sourcePath");
                          String pathDst = (String) arguments.get("destinationPath");
                          int start = (int) arguments.get("startMs");
                          int end = (int) arguments.get("endMs");
                          if (pathSrc != null && pathDst != null) {
                              File fileSrc = new File(pathSrc);
                              File fileDst = new File(pathDst);
                              if (fileSrc.exists() && fileSrc.isFile()) {
                                  try {
                                      startTrim(fileSrc.getPath(), fileDst.getPath(), start, end, true, true);
                                      result.success(pathDst);
                                  } catch (IOException e) {
                                      e.printStackTrace();
                                      result.error(e.getMessage(), null, null);
                                  }
                              }
                          }
                          break;
                      }
                      case "getThumb":
                          if (checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                              requestPermissions(new String[]{Manifest.permission.READ_EXTERNAL_STORAGE}, READ_REQUEST);
                              mTempResult = result;
                              mTempArgs = arguments;

                          } else {
                              createThumb(result, arguments);
                          }
                          break;
                      case "share":
                          share((String) arguments.get("sourcePath"), result);
                          break;
                      case "checkFFMPEG":
                          result.success(FFmpeg.getInstance(this).isSupported());
                          break;
                      case "trimFFMPEG": {
                          String pathSrc = (String) arguments.get("sourcePath");
                          String pathDst = (String) arguments.get("destinationPath");
                          int start = (int) arguments.get("startMs");
                          int end = (int) arguments.get("endMs");
                          trimWithFFMPEG(pathSrc, pathDst, start, end, result);
                          break;
                      }
                  }

              });
  }


    private void share(String path, MethodChannel.Result result) {
        //copy to temp directory from internal storage;
        File tmpFile = new File(this.getCacheDir(), "share.mp4");
        try {
            copyFile(new File(path), tmpFile);
        } catch (IOException e) {
            e.printStackTrace();
            result.error(e.getMessage(), null, null);
        }

        Uri uri = FileProvider.getUriForFile(this, "com.example.video_cutie.fileprovider", tmpFile);

        Intent intent = new Intent(Intent.ACTION_SEND);
        intent.setType( "video/*");

        intent.putExtra(Intent.EXTRA_STREAM, uri);

        startActivity(Intent.createChooser(intent, "Share video..."));
        result.success(null);
    }


    public void startTrim(String srcPath, String dstPath, int startMs, int endMs, boolean useAudio, boolean useVideo)
            throws IOException {
        // Set up MediaExtractor to read from the source.
        MediaExtractor extractor = new MediaExtractor();
        extractor.setDataSource(srcPath);
        int trackCount = extractor.getTrackCount();
        // Set up MediaMuxer for the destination.
        MediaMuxer muxer = new MediaMuxer(dstPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4);
        // Set up the tracks and retrieve the max buffer size for selected
        // tracks.
        SparseIntArray indexMap = new SparseIntArray(trackCount);
        int bufferSize = -1;
        for (int i = 0; i < trackCount; i++) {
            MediaFormat format = extractor.getTrackFormat(i);
            String mime = format.getString(MediaFormat.KEY_MIME);
            boolean selectCurrentTrack = false;
            if (mime.startsWith("audio/") && useAudio) {
                selectCurrentTrack = true;
            } else if (mime.startsWith("video/") && useVideo) {
                selectCurrentTrack = true;
            }
            if (selectCurrentTrack) {
                extractor.selectTrack(i);
                int dstIndex = muxer.addTrack(format);
                indexMap.put(i, dstIndex);
                if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                    int newSize = format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE);
                    bufferSize = newSize > bufferSize ? newSize : bufferSize;
                }
            }
        }
        if (bufferSize < 0) {
            bufferSize = DEFAULT_BUFFER_SIZE;
        }
        // Set up the orientation and starting time for extractor.
        MediaMetadataRetriever retrieverSrc = new MediaMetadataRetriever();
        retrieverSrc.setDataSource(srcPath);
        String degreesString = retrieverSrc.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION);
        if (degreesString != null) {
            int degrees = Integer.parseInt(degreesString);
            if (degrees >= 0) {
                muxer.setOrientationHint(degrees);
            }
        }
        if (startMs > 0) {
            extractor.seekTo(startMs * 1000, MediaExtractor.SEEK_TO_CLOSEST_SYNC);
        }
        // Copy the samples from MediaExtractor to MediaMuxer. We will loop
        // for copying each sample and stop when we get to the end of the source
        // file or exceed the end time of the trimming.
        int offset = 0;
        int trackIndex = -1;
        ByteBuffer dstBuf = ByteBuffer.allocate(bufferSize);
        MediaCodec.BufferInfo bufferInfo = new MediaCodec.BufferInfo();
        muxer.start();
        while (true) {
            bufferInfo.offset = offset;
            bufferInfo.size = extractor.readSampleData(dstBuf, offset);
            if (bufferInfo.size < 0) {
                Log.d(TAG, "Saw input EOS.");
                bufferInfo.size = 0;
                break;
            } else {
                bufferInfo.presentationTimeUs = extractor.getSampleTime();
                if (endMs > 0 && bufferInfo.presentationTimeUs > (endMs * 1000)) {
                    Log.d(TAG, "The current sample is over the trim end time.");
                    break;
                } else {
                    bufferInfo.flags = extractor.getSampleFlags();
                    trackIndex = extractor.getSampleTrackIndex();
                    muxer.writeSampleData(indexMap.get(trackIndex), dstBuf, bufferInfo);
                    extractor.advance();
                }
            }
        }
        muxer.stop();
        muxer.release();
    }

     public void trimWithFFMPEG(String srcPath, String dstPath, int startMs, int endMs, MethodChannel.Result result){

         String hmsStart = String.format("%02d:%02d:%02d", TimeUnit.MILLISECONDS.toHours(startMs),
                 TimeUnit.MILLISECONDS.toMinutes(startMs) - TimeUnit.HOURS.toMinutes(TimeUnit.MILLISECONDS.toHours(startMs)),
                 TimeUnit.MILLISECONDS.toSeconds(startMs) - TimeUnit.MINUTES.toSeconds(TimeUnit.MILLISECONDS.toMinutes(startMs)));

         String hmsEnd = String.format("%02d:%02d:%02d", TimeUnit.MILLISECONDS.toHours(endMs),
                 TimeUnit.MILLISECONDS.toMinutes(endMs) - TimeUnit.HOURS.toMinutes(TimeUnit.MILLISECONDS.toHours(endMs)),
                 TimeUnit.MILLISECONDS.toSeconds(endMs) - TimeUnit.MINUTES.toSeconds(TimeUnit.MILLISECONDS.toMinutes(endMs)));

         String[] cmd = {"-ss", hmsStart, "-to", hmsEnd, "-i", srcPath, "-async", "1", dstPath};
         
         FFmpeg ffmpeg = FFmpeg.getInstance(this);
         // to execute "ffmpeg -version" command you just need to pass "-version"
         ffmpeg.execute(cmd, new ExecuteBinaryResponseHandler() {

             @Override
             public void onStart() {
                 Log.d(TAG, "ffmpeg started");
             }

             @Override
             public void onProgress(String message) {
                 Log.d(TAG, "ffmpeg progress: " + message);
             }

             @Override
             public void onFailure(String message) {
                 Log.d(TAG, "ffmpeg failure: " + message);
                 result.error(message, null, null);
             }

             @Override
             public void onSuccess(String message) {
                 Log.d(TAG, "ffmpeg success: " + message);
                 result.success(dstPath);
             }

             @Override
             public void onFinish() {
                Log.d(TAG, "ffmpeg finished");
             }

         });
         
     }

  private void createThumb(MethodChannel.Result result, Map<String, Object> arguments){
      String pathSrc = (String) arguments.get("sourcePath");

      File file = new File(pathSrc);

      if(!file.exists()){
          result.error("file_not_exists", pathSrc,null);
          return;
      }

      Bitmap bitmap = ThumbnailUtils.createVideoThumbnail(file.getAbsolutePath(), MediaStore.Video.Thumbnails.MINI_KIND);

      String sourceFileName = getFileName(Uri.parse(pathSrc).getLastPathSegment());
      File thumbDir = new File(getDataDir() + File.separator + "app_flutter"+ File.separator + "thumbs" + File.separator);

      if (!thumbDir.exists()) {
          thumbDir.mkdirs();
      }

      String thumbFile = new File(thumbDir + File.separator + sourceFileName).getPath();

      try {
          FileOutputStream out = new FileOutputStream(new File(thumbFile + ".jpg"));
          bitmap.compress(Bitmap.CompressFormat.JPEG, 60, out);
          out.flush();
          out.close();

          result.success(thumbFile + ".jpg");
      } catch (IOException e) {
          e.printStackTrace();
          result.error(e.getMessage(), null, null);
      }
  }


    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        switch (requestCode) {
            case READ_REQUEST: {
                // If request is cancelled, the result arrays are empty.
                if (grantResults.length > 0  && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    createThumb(mTempResult,mTempArgs);
                } else {
                    mTempResult.error("permission_denied", null, null);
                }
                mTempResult = null;
                mTempArgs = null;
            }
        }
    }


    private static final Pattern ext = Pattern.compile("(?<=.)\\.[^.]+$");

    private String getFileName(String s) {
        return ext.matcher(s).replaceAll("");
    }

    public static void copyFile(File sourceFile, File destFile) throws IOException {
        if (!destFile.getParentFile().exists())
            destFile.getParentFile().mkdirs();

        if (!destFile.exists()) {
            destFile.createNewFile();
        }

        FileChannel source = null;
        FileChannel destination = null;

        try {
            source = new FileInputStream(sourceFile).getChannel();
            destination = new FileOutputStream(destFile).getChannel();
            destination.transferFrom(source, 0, source.size());
        } finally {
            if (source != null) {
                source.close();
            }
            if (destination != null) {
                destination.close();
            }
        }
    }
}
