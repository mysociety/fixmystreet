// ********************************************************************************
//details.java
//This file is where most of the work of the application happens. It collects the 
//subject of the problem, plus the user's name and email, from the Android form.
//It uploads them to FixMyStreet, and shows a success or failure message.
//
//********************************************************************************

package com.android.fixmystreet;

import java.util.regex.*;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
//import android.util.Log;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.EditText;

public class Details extends Activity {
	private EditText nameET;
	private EditText emailET;
	private EditText subjectET;
	String storedName;
	String storedEmail;
	private String subject;
	private String name;
	private String email;
	private View submitButton;
	//private static final String LOG_TAG = "Details";
	public static final String PREFS_NAME = "FMS_Settings";
	final int NAME_WARNING = 999;
	final int SUBJECT_WARNING = 998;
	final int EMAIL_WARNING = 997;
	private Bundle extras;

	/** Called when the activity is first created. */
	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);

		// set up the page
		setContentView(R.layout.details);
		nameET = (EditText) findViewById(R.id.name_text);
		emailET = (EditText) findViewById(R.id.email_text);
		subjectET = (EditText) findViewById(R.id.subject_text);
		submitButton = this.findViewById(R.id.submit_button);

		// set the button listeners
		setListeners();

		// fill in name/email, if already defined
		// NB - from settings, rather than from bundle...
		SharedPreferences settings = getSharedPreferences(PREFS_NAME, 0);
		name = settings.getString("myName", "");
		email = settings.getString("myEmail", "");
		nameET.setText(name);
		emailET.setText(email);

		extras = getIntent().getExtras();
		if (extras != null) {
			// Details extras
			subject = extras.getString("subject");
		}
		if (subject != null) {
			subjectET.setText(subject);
		}
	}

	private void setListeners() {
		// Save info and pass back to Home activity
		submitButton.setOnClickListener(new OnClickListener() {
			public void onClick(View v) {
				subject = subjectET.getText().toString();
				email = emailET.getText().toString();
				name = nameET.getText().toString();
				if (!textFieldsAreValid(subject)) {
					showDialog(SUBJECT_WARNING);
				} else if (!textFieldsAreValid(name)) {
					showDialog(NAME_WARNING);
				} else if (!isValidEmailAddress(email)) {
					showDialog(EMAIL_WARNING);
				} else {
					if (true) {
						Intent i = new Intent(Details.this, Home.class);
						extras.putString("name", name);
						extras.putString("email", email);
						extras.putString("subject", subject);
						i.putExtras(extras);
						startActivity(i);
					}
				}
			}
		});
	}

	// **********************************************************************
	// textFieldsAreValid: Make sure that fields aren't blank
	// **********************************************************************
	public static boolean textFieldsAreValid(String field) {
		if (field == null || field.length() == 0 || field.trim().length() == 0) {
			return false;
		}
		return true;
	}

	// **********************************************************************
	// isValidEmailAddress: Check the email address is OK
	// **********************************************************************
	public static boolean isValidEmailAddress(String emailAddress) {
		String emailRegEx;
		Pattern pattern;
		// Regex for a valid email address
		emailRegEx = "^[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,4}$";
		// Compare the regex with the email address
		pattern = Pattern.compile(emailRegEx);
		Matcher matcher = pattern.matcher(emailAddress);
		if (!matcher.find()) {
			return false;
		}
		return true;
	}

	// **********************************************************************
	// onCreateDialog: Dialog warnings
	// **********************************************************************
	@Override
	protected Dialog onCreateDialog(int id) {
		switch (id) {
		case SUBJECT_WARNING:
			return new AlertDialog.Builder(Details.this).setTitle("Subject")
					.setPositiveButton("OK",
							new DialogInterface.OnClickListener() {
								public void onClick(DialogInterface dialog,
										int whichButton) {
								}
							}).setMessage("Please enter a subject!").create();
		case NAME_WARNING:
			return new AlertDialog.Builder(Details.this)
					.setTitle("Name")
					.setPositiveButton("OK",
							new DialogInterface.OnClickListener() {
								public void onClick(DialogInterface dialog,
										int whichButton) {
								}
							})
					.setMessage(
							"Please enter your name. We'll remember it for next time.")
					.create();

		case EMAIL_WARNING:
			return new AlertDialog.Builder(Details.this)
					.setTitle("Email")
					.setPositiveButton("OK",
							new DialogInterface.OnClickListener() {
								public void onClick(DialogInterface dialog,
										int whichButton) {
								}
							})
					.setMessage(
							"Please enter a valid email address. We'll remember it for next time.")
					.create();

		}
		return null;
	}

	// Save user's name and email, if already defined
	@Override
	protected void onStop() {
		super.onStop();

		name = nameET.getText().toString();
		email = emailET.getText().toString();

		// Save user preferences
		SharedPreferences settings = getSharedPreferences(PREFS_NAME, 0);
		SharedPreferences.Editor editor = settings.edit();
		editor.putString("myName", name);
		editor.putString("myEmail", email);

		// Don't forget to commit your edits!!!
		editor.commit();
	}

	// Look at this - is it working ok
	// public boolean testProviders() {
	// Log.e(LOG_TAG, "testProviders");
	// // StringBuilder sb = new StringBuilder("Enabled Providers");
	// // List<String> providers = locationmanager.getProviders(true);
	// // for (String provider : providers) {
	// // Log.e(LOG_TAG, "Provider = " + provider);
	// // listener = new LocationListener() {
	// // public void onLocationChanged(Location location) {
	// // }
	// //
	// // public void onProviderDisabled(String provider) {
	// // }
	// //
	// // public void onProviderEnabled(String provider) {
	// // }
	// //
	// // public void onStatusChanged(String provider, int status,
	// // Bundle extras) {
	// // }
	// // };
	// //
	// // locationmanager.requestLocationUpdates(provider, 0, 0, listener);
	// //
	// // sb.append("\n*").append(provider).append(": ");
	// //
	// // Location location = locationmanager.getLastKnownLocation(provider);
	// //
	// // if (location != null) {
	// // latitude = location.getLatitude();
	// // longitude = location.getLongitude();
	// // latString = latitude.toString();
	// // longString = longitude.toString();
	// // Log.e(LOG_TAG, "Latitude = " + latString);
	// // Log.e(LOG_TAG, "Longitude = " + longString);
	// // if (provider == "gps") {
	// // // Only bother with GPS if available
	// // return true;
	// // }
	// // } else {
	// // Log.e(LOG_TAG, "Location is null");
	// // return false;
	// // }
	// // }
	// // LocationManager lm = (LocationManager)
	// // context.getSystemService(Context.LOCATION_SERVICE);
	// //
	// // Location loc = lm.getLastKnownLocation("gps");
	// // if (loc == null)
	// // {
	// // locType = "Network";
	// // loc = lm.getLastKnownLocation("network");
	// // }
	// //
	// // textMsg.setText(sb);
	//
	// return true;
	// }
}
