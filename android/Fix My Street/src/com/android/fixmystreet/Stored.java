package com.android.fixmystreet;

import android.content.Context;
import android.os.Bundle;
import android.preference.PreferenceActivity;
import android.preference.PreferenceManager;

public class Stored extends PreferenceActivity {
	// Option names and default values
	private static final String OPT_EMAIL = "email";
	private static final boolean OPT_EMAIL_DEF = true;
	private static final String OPT_NAME = "name";
	private static final boolean OPT_NAME_DEF = true;

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		// addPreferencesFromResource(R.xml.settings);
	}

	// Get email, if stored
	public static boolean getEmail(Context context) {
		return PreferenceManager.getDefaultSharedPreferences(context)
				.getBoolean(OPT_EMAIL, OPT_EMAIL_DEF);
	}

	// Get name, if stored
	public static boolean getName(Context context) {
		return PreferenceManager.getDefaultSharedPreferences(context)
				.getBoolean(OPT_NAME, OPT_NAME_DEF);
	}
}