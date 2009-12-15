/**
* Portsurf Ltd functions
**/

function resetMarkers(){
	$("#s1:first-child").html("default");
	$("#s2:first-child").html("relaxed light");
	$("#s3:first-child").html("dark");
	$("#s4:first-child").html("relaxed dark");
}

$(document).ready(function(){
	
	/**
	* Show the style switcher - it's hidden without javascript
	**/
	$("#switcher").show();
	
	
	/**
	* Clear the search box
	**/
	$(".search").focus(function(){
		if(this.value=="Please enter your search"){
			this.value="";
		}
	});
	
	/**
	* Highlight the appropriate style preference
	**/

		
		/**
		* Page loads
		**/	
		
		// reset markers first
		resetMarkers();
		
		// set markers
		var sty=$.cookie('style');
		switch(sty){
			case "default":
				$("#s1:first-child").html("<strong>default</strong>");
				break;
				
			case "relaxed light":
				$("#s2:first-child").html("<strong>relaxed light</strong>");
				break;
				
			case "dark":
				$("#s3:first-child").html("<strong>dark</strong>");
				break;
				
			case "relaxed dark":
				$("#s4:first-child").html("<strong>relaxed dark</strong>");
				break;
				
			default:
				$("#s1:first-child").html("<strong>default</strong>");
				break;
				
		}

		/**
		* Clicks
		**/
		
		$("#s1").click(function(){
			resetMarkers();
			$("#s1:first-child").html("<strong>default</strong>");
		});
		
		$("#s2").click(function(){
			resetMarkers();
			$("#s2:first-child").html("<strong>relaxed light</strong>");
		});	
		
		$("#s3").click(function(){
			resetMarkers();
			$("#s3:first-child").html("<strong>dark</strong>");
		});	
		
		$("#s4").click(function(){
			resetMarkers();
			$("#s4:first-child").html("<strong>relaxed dark</strong>");
		});
	
	// Intentionally blank due to fake indenting...
	
});

