// **************************************************************************
// Home.java
// **************************************************************************
package com.android.fixmystreet;

import java.io.File;
import java.io.FileInputStream; 
import java.io.IOException;
import java.io.InputStream; 

import org.apache.commons.httpclient.HttpClient;
import org.apache.commons.httpclient.methods.PostMethod;
import org.apache.commons.httpclient.methods.multipart.ByteArrayPartSource;
import org.apache.commons.httpclient.methods.multipart.FilePart;
import org.apache.commons.httpclient.methods.multipart.MultipartRequestEntity;
import org.apache.commons.httpclient.methods.multipart.Part;
import org.apache.commons.httpclient.methods.multipart.StringPart;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.app.ProgressDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;

import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.net.Uri;
import android.os.Bundle;
import android.os.Environment;
import android.os.Handler;
import android.util.Log;
import android.view.Menu;
import android.view.MenuItem;
import android.widget.Button;
import android.content.res.Resources;
import android.graphics.drawable.Drawable;
import android.provider.MediaStore;
import android.view.View;
import android.view.View.OnClickListener;

public class Home extends Activity {
	// ****************************************************
	// Local variables
	// ****************************************************
	//private static final String LOG_TAG = "Home";
	private Button btnReport;
	private Button btnDetails;
	private Button btnPicture;
	// Info that's been passed from other activities
	private Boolean haveDetails = false;
	private Boolean havePicture = false;
	private String name = null;
	private String email = null;
	private String subject = null;
	// Location info
	LocationManager locationmanager;
	LocationListener listener;
	private Double latitude;
	private Double longitude;
	private String latString = "";
	private String longString = "";
	// hacky way of checking the results
	private static int globalStatus = 13;
	private static final int SUCCESS = 0;
	private static final int LOCATION_NOT_FOUND = 1;
	private static final int UPLOAD_ERROR = 2;
	private static final int UPLOAD_ERROR_SERVER = 3;
	private static final int LOCATION_NOT_ACCURATE = 4;
	private static final int PHOTO_NOT_FOUND = 5;
	private String serverResponse;
	// Thread handling
	ProgressDialog myProgressDialog = null;
	private ProgressDialog pd;
	final Handler mHandler = new Handler();
	final Runnable mUpdateResults = new Runnable() {
		public void run() {
			pd.dismiss();
			updateResultsInUi();
		}
	};
	private Bundle extras;
	//private Bitmap bmp = null;

	// Called when the activity is first created
	@Override
	public void onCreate(Bundle icicle) {
		super.onCreate(icicle);
		setContentView(R.layout.home);

		testProviders();
		// showDialog();

		btnDetails = (Button) findViewById(R.id.details_button);
		btnPicture = (Button) findViewById(R.id.camera_button);
		btnReport = (Button) findViewById(R.id.report_button);
		btnReport.setVisibility(View.GONE);

		if (icicle != null) {
			havePicture = icicle.getBoolean("photo");
		}

		extras = getIntent().getExtras();
		checkBundle();
		setListeners();
	}

	@Override
	protected void onPause() {
		//Log.d("onPause, havePicture = " + havePicture);
		removeListeners();
		saveState();
		super.onPause();
	}

	@Override
	protected void onStop() {
		//Log.d(LOG_TAG, "onStop, havePicture = " + havePicture);
		removeListeners();
		super.onStop();
	}

	@Override
	public void onRestart() {
		//Log.d(LOG_TAG, "onRestart, havePicture = " + havePicture);
		testProviders();
		checkBundle();
		super.onRestart();
	}

	// ****************************************************
	// checkBundle - check the extras that have been passed
	// is the user able to upload things yet, or not?
	// ****************************************************
	private void checkBundle() {
		//Log.d(LOG_TAG, "checkBundle");

		// Get the status icons...
		Resources res = getResources();
		Drawable checked = res.getDrawable(R.drawable.done);

		if (extras != null) {
			// Details extras
			name = extras.getString("name");
			email = extras.getString("email");
			subject = extras.getString("subject");
			havePicture = extras.getBoolean("photo");

			// Do we have the details?
			if ((name != null) && (email != null) && (subject != null)) {
				haveDetails = true;
				//Log.d(LOG_TAG, "Have all details");
				checked.setBounds(0, 0, checked.getIntrinsicWidth(), checked
						.getIntrinsicHeight());
				// envelope.setBounds(0, 0, envelope.getIntrinsicWidth(),
				// envelope
				// .getIntrinsicHeight());
				btnDetails.setText("Details added: '" + subject + "'");
				btnDetails.setCompoundDrawables(null, null, checked, null);
			} else {
				//Log.d(LOG_TAG, "Don't have details");
			}
		} else {
			extras = new Bundle();
			//Log.d(LOG_TAG, "no Bundle at all");
		}
		//Log.d(LOG_TAG, "havePicture = " + havePicture);

		// Do we have the photo?
		if (havePicture) {

			checked.setBounds(0, 0, checked.getIntrinsicWidth(), checked
					.getIntrinsicHeight());
			// camera.setBounds(0, 0, camera.getIntrinsicWidth(), camera
			// .getIntrinsicHeight());
			btnPicture.setCompoundDrawables(null, null, checked, null);
			btnPicture.setText("Photo taken");
			// code for if we wanted to show a thumbnail - works but crashes
			// ImageView iv = (ImageView) findViewById(R.id.thumbnail);
			// try {
			// Log.d(LOG_TAG, "Trying to look for FMS photo");
			// FileInputStream fstream = null;
			// fstream = new FileInputStream(Environment
			// .getExternalStorageDirectory()
			// + "/" + "FMS_photo.jpg");
			// Log.d("Looking for file at ", Environment
			// .getExternalStorageDirectory()
			// + "/" + "FMS_photo.jpg");
			// bmp = BitmapFactory.decodeStream(fstream);
			// // bmp = BitmapFactory
			// // .decodeStream(openFileInput("FMS_photo.jpg"));
			// iv.setImageBitmap(bmp);
			// System.gc();
			// } catch (FileNotFoundException e) {
			// // TODO Auto-generated catch block
			// Log.d(LOG_TAG, "FMS photo not found");
			// e.printStackTrace();
			// }
		}

		// We have details and photo - show the Report button
		if (haveDetails && havePicture) {
			btnReport.setVisibility(View.VISIBLE);
		}
	}

	// ****************************************************
	// setListeners - set the button listeners
	// ****************************************************

	private void setListeners() {
		btnDetails.setOnClickListener(new OnClickListener() {
			public void onClick(View v) {
				Intent i = new Intent(Home.this, Details.class);
				extras.putString("name", name);
				extras.putString("email", email);
				extras.putString("subject", subject);
				i.putExtras(extras);
				startActivity(i);
			}
		});
		btnPicture.setOnClickListener(new OnClickListener() {
			public void onClick(View v) {
				File photo = new File(
						Environment.getExternalStorageDirectory(),
						"FMS_photo.jpg");
				if (photo.exists()) {
					photo.delete();
				}
				Intent imageCaptureIntent = new Intent(
						MediaStore.ACTION_IMAGE_CAPTURE);
				imageCaptureIntent.putExtra(MediaStore.EXTRA_OUTPUT, Uri
						.fromFile(photo));
				startActivityForResult(imageCaptureIntent, 1);
			}
		});
		btnReport.setOnClickListener(new OnClickListener() {
			public void onClick(View v) {
				uploadToFMS();
			}
		});
	}

	@Override
	public void onActivityResult(int requestCode, int resultCode, Intent data) {
		//Log.d(LOG_TAG, "onActivityResult");
		//Log.d(LOG_TAG, "Activity.RESULT_OK code = " + Activity.RESULT_OK);
		//Log.d(LOG_TAG, "resultCode = " + resultCode + "requestCode = "
		//	+ requestCode);
		if (resultCode == Activity.RESULT_OK && requestCode == 1) {
			havePicture = true;
			extras.putBoolean("photo", true);
		}
		//testProviders();
		//Log.d(LOG_TAG, "havePicture = " + havePicture.toString());
	}

	@Override
	protected void onSaveInstanceState(Bundle outState) {
		super.onSaveInstanceState(outState);
		//Log.d(LOG_TAG, "onSaveInstanceState");
		if (havePicture != null) {
			// Log.d(LOG_TAG, "mRowId = " + mRowId);
			outState.putBoolean("photo", havePicture);
		}
		// if (name != null) {
		// // Log.d(LOG_TAG, "mRowId = " + mRowId);
		// outState.putString("name", name);
		// }
		// if (email != null) {
		// // Log.d(LOG_TAG, "mRowId = " + mRowId);
		// outState.putString("email", email);
		// }
		// if (subject != null) {
		// // Log.d(LOG_TAG, "mRowId = " + mRowId);
		// outState.putString("subject", subject);
		// }
	}

	// TODO - save bits and pieces here
	private void saveState() {
		// Log.d(LOG_TAG, "saveState");
		// String body = mBodyText.getText().toString();
		// String title = mTitleText.getText().toString();
		// // Log.d(LOG_TAG, "title valid");
		// if (mRowId == null) {
		// // Log.d(LOG_TAG, "mRowId = null, creating note");
		// long id = mDbHelper.createNote(body, title);
		// if (id > 0) {
		// mRowId = id;
		// // Log.d(LOG_TAG, "Set mRowId to " + mRowId);
		// }
		// } else {
		// // Log.d(LOG_TAG, "mRowId = " + mRowId + ", updating note");
		// mDbHelper.updateNote(mRowId, body, title);
		// }
	}

	// **********************************************************************
	// uploadToFMS: uploads details, handled via a background thread
	// Also checks the age and accuracy of the GPS data first
	// **********************************************************************
	private void uploadToFMS() {
		//Log.d(LOG_TAG, "uploadToFMS");
		pd = ProgressDialog
				.show(
						this,
						"Uploading, please wait...",
						"Uploading. This can take up to a minute, depending on your connection speed. Please be patient!",
						true, false);
		Thread t = new Thread() {
			public void run() {
				doUploadinBackground();
				mHandler.post(mUpdateResults);
			}
		};
		t.start();
	}

	private void updateResultsInUi() {
		if (globalStatus == UPLOAD_ERROR) {
			showDialog(UPLOAD_ERROR);
		} else if (globalStatus == UPLOAD_ERROR_SERVER) {
			showDialog(UPLOAD_ERROR_SERVER);
		} else if (globalStatus == LOCATION_NOT_FOUND) {
			showDialog(LOCATION_NOT_FOUND);
		} else if (globalStatus == PHOTO_NOT_FOUND) {
			showDialog(PHOTO_NOT_FOUND);
		} else if (globalStatus == LOCATION_NOT_ACCURATE) {
			showDialog(LOCATION_NOT_ACCURATE);
		} else {
			// Success! - Proceed to the success activity!
			Intent i = new Intent(Home.this, Success.class);
			i.putExtra("latString", latString);
			i.putExtra("lonString", longString);
			startActivity(i);
		}
	}

	// **********************************************************************
	// onCreateDialog: Dialog warnings
	// **********************************************************************
	@Override
	protected Dialog onCreateDialog(int id) {
		switch (id) {
		case UPLOAD_ERROR:
			return new AlertDialog.Builder(Home.this)
					.setTitle("Upload error")
					.setPositiveButton("OK",
							new DialogInterface.OnClickListener() {
								public void onClick(DialogInterface dialog,
										int whichButton) {
								}
							})
					.setMessage(
							"Sorry, there was an error uploading - maybe the network connection is down? Please try again later.")
					.create();
		case UPLOAD_ERROR_SERVER:
			return new AlertDialog.Builder(Home.this)
					.setTitle("Upload error")
					.setPositiveButton("OK",
							new DialogInterface.OnClickListener() {
								public void onClick(DialogInterface dialog,
										int whichButton) {
								}
							})
					.setMessage(
							"Sorry, there was an error uploading. Please try again later. The server response was: "
									+ serverResponse).create();
		case LOCATION_NOT_FOUND:
			return new AlertDialog.Builder(Home.this)
					.setTitle("GPS problem")
					.setPositiveButton("OK",
							new DialogInterface.OnClickListener() {
								public void onClick(DialogInterface dialog,
										int whichButton) {
								}
							})
					.setMessage(
							"Could not get location! Can you see the sky? Please try again later.")
					.create();
		case PHOTO_NOT_FOUND:
			return new AlertDialog.Builder(Home.this).setTitle("No photo")
					.setPositiveButton("OK",
							new DialogInterface.OnClickListener() {
								public void onClick(DialogInterface dialog,
										int whichButton) {
								}
							}).setMessage("Photo not found!").create();
		case LOCATION_NOT_ACCURATE:
			return new AlertDialog.Builder(Home.this)
					.setTitle("GPS problem")
					.setPositiveButton("OK",
							new DialogInterface.OnClickListener() {
								public void onClick(DialogInterface dialog,
										int whichButton) {
								}
							})
					.setMessage(
							"Sorry, your GPS location is not accurate enough. Can you see the sky?")
					.create();
		}
		return null;
	}

	// **********************************************************************
	// doUploadinBackground: POST request to FixMyStreet
	// **********************************************************************
	private boolean doUploadinBackground() {
		//Log.d(LOG_TAG, "doUploadinBackground");

		String responseString = null;
		PostMethod method;

		// DefaultHttpClient httpClient;
		// HttpPost httpPost;
		// HttpResponse response;
		// HttpEntity entity;
		// UrlEncodedFormEntity urlentity;
		// // get the photo data from the URI
		// // Uri uri = (Uri) content.getParcelable("URI");
		// Context context = getApplicationContext();
		// ContentResolver cR = context.getContentResolver();
		//
		// // Get the type of the file
		// MimeTypeMap mime = MimeTypeMap.getSingleton();
		// String type = mime.getExtensionFromMimeType(cR.getType(uri));
		//
		// // Get the InputStream
		// InputStream in = null;
		//		
		// try {
		// in = cR.openInputStream(uri);
		// } catch (FileNotFoundException e) {
		// // TODO Auto-generated catch block
		// e.printStackTrace();
		// }
		//
		// if (in == null) {
		// globalStatus = PHOTO_NOT_FOUND;
		// return false;
		// }
		//
		// // Setting the InputStream Body
		// InputStreamBody body = new InputStreamBody(in, "image." + type);

		// TODO - check location updates
		Location location = locationmanager
				.getLastKnownLocation(LocationManager.GPS_PROVIDER);

		if (location != null) {
			// TODO - put back in
			long currentTime = System.currentTimeMillis();
			long gpsTime = location.getTime();
			long timeDiffSecs = (currentTime - gpsTime) / 1000;
			//Log.e(LOG_TAG, "Location accuracy = " + location.getAccuracy());
			//Log.e(LOG_TAG, "Location age = " + timeDiffSecs);
			if ((location.getAccuracy() > 150) || (timeDiffSecs > 15)) {
				//Log.e(LOG_TAG, "Location not accurate");
				globalStatus = LOCATION_NOT_ACCURATE;
				return false;
			}
			latitude = location.getLatitude();
			longitude = location.getLongitude();
			latString = latitude.toString();
			longString = longitude.toString();
			//Log.e(LOG_TAG, "Latitude = " + latString);
			//Log.e(LOG_TAG, "Longitude = " + longString);
		} else {
			//Log.e(LOG_TAG, "Location is null");
			globalStatus = LOCATION_NOT_FOUND;
			return false;
		}

		// TEMP - testing
		// latString = "51.5";
		// longString = "-0.116667";

		method = new PostMethod("http://www.fixmystreet.com/import");

		try {

			// Bitmap bitmap;
			// ByteArrayOutputStream imageByteStream;
			byte[] imageByteArray = null;
			// ByteArrayPartSource fileSource;

			HttpClient client = new HttpClient();
			client.getHttpConnectionManager().getParams().setConnectionTimeout(
					100000);

			// InputStream in =
			// this.getResources().openRawResource(R.drawable.tom);
			// bitmap = android.provider.MediaStore.Images.Media.getBitmap(
			// getContentResolver(), uri);
			// imageByteStream = new ByteArrayOutputStream();

			// if (bitmap == null) {
			// Log.d(LOG_TAG, "No bitmap");
			// }

			// Compress bmp to jpg, write to the bytes output stream
			// bitmap.compress(Bitmap.CompressFormat.JPEG, 80, imageByteStream);

			// Turn the byte stream into a byte array, write to imageData
			// imageByteArray = imageByteStream.toByteArray();

			File f = new File(Environment.getExternalStorageDirectory(),
					"FMS_photo.jpg");

			// TODO - add a check here
			if (!f.exists()) {
			}
			imageByteArray = getBytesFromFile(f);

//			Log
//					.d(LOG_TAG, "len of data is " + imageByteArray.length
//							+ " bytes");

			// fileSource = new ByteArrayPartSource("photo", imageData);
			FilePart photo = new FilePart("photo", new ByteArrayPartSource(
					"photo", imageByteArray));

			photo.setContentType("image/jpeg");
			photo.setCharSet(null);

			Part[] parts = { new StringPart("service", "your Android phone"),
					new StringPart("subject", subject),
					new StringPart("name", name),
					new StringPart("email", email),
					new StringPart("lat", latString),
					new StringPart("lon", longString), photo };

			method.setRequestEntity(new MultipartRequestEntity(parts, method
					.getParams()));

			client.executeMethod(method);
			responseString = method.getResponseBodyAsString();
			method.releaseConnection();

			Log.e("httpPost", "Response status: " + responseString);
			Log.e("httpPost", "Latitude = " + latString + " and Longitude = "
					+ longString);

			// textMsg.setText("Bitmap (bitmap) = " + bitmap.toString()
			// + " AND imageByteArray (byte[]) = "
			// + imageByteArray.toString()
			// + " AND imageByteStream (bytearrayoutputstream) = "
			// + imageByteStream.toString());

		} catch (Exception ex) {
			//Log.v(LOG_TAG, "Exception", ex);
			globalStatus = UPLOAD_ERROR;
			serverResponse = "";
			return false;
		} finally {
			method.releaseConnection();
		}

		if (responseString.equals("SUCCESS")) {
			// launch the Success page
			globalStatus = SUCCESS;
			return true;
		} else {
			// print the response string?
			serverResponse = responseString;
			globalStatus = UPLOAD_ERROR;
			return false;
		}
	}

	public void testProviders() {
		//Log.e(LOG_TAG, "testProviders");
		// Register for location listener
		String location_context = Context.LOCATION_SERVICE;
		locationmanager = (LocationManager) getSystemService(location_context);
		// StringBuilder sb = new StringBuilder("Enabled Providers");
		// List<String> providers = locationmanager.getProviders(true);
		// for (String provider : providers) {
		listener = new LocationListener() {
			public void onLocationChanged(Location location) {
			}

			public void onProviderDisabled(String provider) {
			}

			public void onProviderEnabled(String provider) {
			}

			public void onStatusChanged(String provider, int status,
					Bundle extras) {
			}
		};
		locationmanager.requestLocationUpdates(LocationManager.GPS_PROVIDER, 0,
				0, listener);
		if (!locationmanager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
			buildAlertMessageNoGps();
		}
	}

	private void buildAlertMessageNoGps() {
		final AlertDialog.Builder builder = new AlertDialog.Builder(this);
		builder
				.setMessage(
						"Your GPS seems to be disabled. Do you want to turn it on now?")
				.setCancelable(false).setPositiveButton("Yes",
						new DialogInterface.OnClickListener() {
							public void onClick(
									@SuppressWarnings("unused") final DialogInterface dialog,
									@SuppressWarnings("unused") final int id) {
								Intent j = new Intent();
								j
										.setAction("android.settings.LOCATION_SOURCE_SETTINGS");
								startActivity(j);
							}
						}).setNegativeButton("No",
						new DialogInterface.OnClickListener() {
							public void onClick(final DialogInterface dialog,
									@SuppressWarnings("unused") final int id) {
								dialog.cancel();
							}
						});
		final AlertDialog alert = builder.create();
		alert.show();
	}

	public void removeListeners() {
		//Log.e(LOG_TAG, "removeListeners");
		if (locationmanager != null) {
			locationmanager.removeUpdates(listener);
		}
		locationmanager = null;
		//Log.d(LOG_TAG, "Removed " + listener.toString());
	}

	// ****************************************************
	// Options menu functions
	// ****************************************************

	// TODO - add Bundles for these?
	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		super.onCreateOptionsMenu(menu);
		MenuItem helpItem = menu.add(0, 0, 0, "Help");
		MenuItem aboutItem = menu.add(0, 1, 0, "About");
		aboutItem.setIcon(android.R.drawable.ic_menu_info_details);
		helpItem.setIcon(android.R.drawable.ic_menu_help);
		return true;
	}

	@Override
	public boolean onOptionsItemSelected(MenuItem item) {
		switch (item.getItemId()) {
		case 0:
			Intent i = new Intent(Home.this, Help.class);
			if (extras != null) {
				i.putExtras(extras);
			}
			startActivity(i);
			return true;
		case 1:
			Intent j = new Intent(Home.this, About.class);
			if (extras != null) {
				j.putExtras(extras);
			}
			startActivity(j);
			return true;
		}
		return false;
	}

	// read the photo file into a byte array...
	public static byte[] getBytesFromFile(File file) throws IOException {
		InputStream is = new FileInputStream(file);

		// Get the size of the file
		long length = file.length();

		// You cannot create an array using a long type.
		// It needs to be an int type.
		// Before converting to an int type, check
		// to ensure that file is not larger than Integer.MAX_VALUE.
		if (length > Integer.MAX_VALUE) {
			// File is too large
		}

		// Bitmap bitmap;
		// ByteArrayOutputStream imageByteStream;
		// byte[] imageByteArray = null;

		// InputStream in =
		// this.getResources().openRawResource(R.drawable.tom);
		// bitmap = android.provider.MediaStore.Images.Media.getBitmap(
		// getContentResolver(), uri);
		// imageByteStream = new ByteArrayOutputStream();

		// Compress bmp to jpg, write to the bytes output stream
		// bitmap.compress(Bitmap.CompressFormat.JPEG, 80, imageByteStream);

		// Turn the byte stream into a byte array, write to imageData
		// imageByteArray = imageByteStream.toByteArray();

		// Create the byte array to hold the data
		byte[] bytes = new byte[(int) length];

		// Read in the bytes
		int offset = 0;
		int numRead = 0;
		while (offset < bytes.length
				&& (numRead = is.read(bytes, offset, bytes.length - offset)) >= 0) {
			offset += numRead;
		}

		// Ensure all the bytes have been read in
		if (offset < bytes.length) {
			throw new IOException("Could not completely read file "
					+ file.getName());
		}

		// Close the input stream and return bytes
		is.close();
		return bytes;
	}
}
