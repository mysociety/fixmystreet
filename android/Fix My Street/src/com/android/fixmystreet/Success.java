//*************************************************************
//
//*************************************************************

package com.android.fixmystreet;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
//import android.util.Log;
import android.view.KeyEvent;
import android.view.Menu;
import android.view.MenuItem;

public class Success extends Activity {

	//private static final String LOG_TAG = "Success";

	/** Called when the activity is first created. */
	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.success);
	}

	// ****************************************************
	// Options menu functions
	// ****************************************************

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		super.onCreateOptionsMenu(menu);
		MenuItem helpItem = menu.add(0, 0, 0, "Home");
		helpItem.setIcon(android.R.drawable.ic_menu_edit);
		return true;
	}

	@Override
	public boolean onOptionsItemSelected(MenuItem item) {
		switch (item.getItemId()) {
		case 0:
			Intent i = new Intent(Success.this, Home.class);
			startActivity(i);
			return true;
		}
		return false;
	}

	// disable the Back key in case things get submitted twice
	public boolean onKeyDown(int keyCode, KeyEvent event) {
		if (keyCode == KeyEvent.KEYCODE_BACK) {
			return true;
		}
		return false;
	}

}