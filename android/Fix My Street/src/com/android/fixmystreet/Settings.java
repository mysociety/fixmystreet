package com.android.fixmystreet;

import android.app.Activity;
import android.os.Bundle;
import android.content.SharedPreferences;

public class Settings extends Activity {
	public static final String PREFS_NAME = "Settings";
  

	    @Override
	    protected void onCreate(Bundle state){         
	       super.onCreate(state);
	    }
	    
	    @Override
	    protected void onStop(){
	       super.onStop();
	    
	       String name = "";
	    String email = "";   
	    
	      // Save user preferences. We need an Editor object to
	      // make changes. All objects are from android.context.Context
	      SharedPreferences settings = getSharedPreferences(PREFS_NAME, 0);
	      SharedPreferences.Editor editor = settings.edit();
	      editor.putString("myName", name);
	      editor.putString("myEmail", email);

	      // Don't forget to commit your edits!!!
	      editor.commit();
	    }
	}
