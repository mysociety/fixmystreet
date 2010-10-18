package com.android.fixmystreet;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager.NameNotFoundException;
import android.os.Bundle;
import android.text.util.Linkify;
import android.view.Menu;
import android.view.MenuItem;
import android.widget.TextView;

public class About extends Activity {

	private Bundle extras = null;
	String versionName = "";

	@Override
	protected void onCreate(Bundle icicle) {
		super.onCreate(icicle);
		setContentView(R.layout.about);
		extras = getIntent().getExtras();
		
		try {
			versionName = getPackageManager().getPackageInfo(getPackageName(),
					0).versionName;
		} catch (NameNotFoundException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}

		// add links
		TextView noteView = (TextView) findViewById(R.id.faq);
		TextView noteView2 = (TextView) findViewById(R.id.faq2);
		noteView2.setText("This application is version " + versionName + " of Fix My Street for Android, written by Anna Powell-Smith. Thanks to Paul for testing.");
		Linkify.addLinks(noteView, Linkify.ALL);
	}

	// ****************************************************
	// Options menu functions
	// ****************************************************

	// TODO - add Bundles for these?
	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		super.onCreateOptionsMenu(menu);
		MenuItem homeItem = menu.add(0, 0, 0, "Home");
		MenuItem aboutItem = menu.add(0, 1, 0, "Help");
		aboutItem.setIcon(android.R.drawable.ic_menu_info_details);
		homeItem.setIcon(android.R.drawable.ic_menu_edit);
		return true;
	}

	@Override
	public boolean onOptionsItemSelected(MenuItem item) {
		switch (item.getItemId()) {
		case 0:
			Intent i = new Intent(About.this, Home.class);
			if (extras != null) {
				i.putExtras(extras);
			}
			startActivity(i);
			return true;
		case 1:
			Intent j = new Intent(About.this, Help.class);
			if (extras != null) {
				j.putExtras(extras);
			}
			startActivity(j);
			return true;
		}
		return false;
	}
}