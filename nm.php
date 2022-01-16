<?php
setlocale(LC_TIME, "de_DE.utf8");

#.htaccess!
#RewriteEngine On
 
#RewriteCond %{SCRIPT_FILENAME} !-d
#RewriteCond %{SCRIPT_FILENAME} !-f

#RewriteRule ^d ./nm.php
#RewriteRule ^d/ ./nm.php
#RewriteRule ^d/(\d+)*$ ./nm.php?v=$1 [L,QSA]

#RewriteRule ^m ./nm.php
#RewriteRule ^m/ ./nm.php
#RewriteRule ^m/(\d+)*$ ./nm.php?v=$1 [L,QSA]

$fontcolor1 = "";
$fontcolor2 = "";
$keycolor = "";
$headline1 = "";

$fontcolor1 = chr(159);
$fontcolor2 = chr(158);  
$keycolor = chr(153);	//light green
$headline1 = chr(158);	//yellow

// Feed-URL des RSS-Feeds
$feed_url = 'https://www.tagesschau.de/xml/rss2/';



// Wie alt in Sekunden darf der Cache sein? (1800 s entsprechen einer halben Stunde)
$feedcache_max_age = 1800;

// Wie viele Einträge sollen angezeigt werden?
$max_entries = 15;

$exitkey=c64key("E",$keycolor ,$fontcolor1)."=EXIT";
$menukey=c64key("M",$keycolor ,$fontcolor1)."=MEN".chr(18).chr(191).chr(146);
$infokex=c64key("I",$keycolor ,$fontcolor1)."=INFO"; 
$pagekex=c64key("*",$keycolor ,$fontcolor1)."=TASTE"; 

function c64encode($str){
	$str = strip_tags(strtoupper($str));
	$search = array('À','á','"',"Ä","Ö","Ü","ä","ö","ü","ß","´");
	$replace = array(chr(186),chr(186),chr(18).chr(251).chr(146),chr(18).chr(189).chr(146),chr(18).chr(190).chr(146),chr(18).chr(191).chr(146),chr(18).chr(189).chr(146),chr(18).chr(190).chr(146),chr(18).chr(191).chr(146),chr(18).chr(188).chr(146),chr(18).chr(103).chr(146));
	$str = str_replace($search, $replace, $str);
	return $str;
}

function c64key($str,$keycolor1,$fontcolor1){

	switch ($str) {
		case 10:
			$str="0";// 10 = Taste 0
			break;
		case 11:
			$str="Z";// 11
			break;
		case 12:
			$str="X";// 12
			break;
		case 13:
			$str="C";// 13
			break;
		case 14:
			$str="V";// 14
			break;			
		case 15:
			$str="B";// 15
			break;			
	}	
	
	$str=chr(18).$str.chr(146); //Revers ON + str + revers off
	$str=$keycolor1.$str.$fontcolor1;
	return $str;
}

$trans = array(
    'Monday'    => 'Montag',
    'Tuesday'   => 'Dienstag',
    'Wednesday' => 'Mittwoch',
    'Thursday'  => 'Donnerstag',
    'Friday'    => 'Freitag',
    'Saturday'  => 'Samstag',
    'Sunday'    => 'Sonntag',
    'Mon'       => 'Mo',
    'Tue'       => 'Di',
    'Wed'       => 'Mi',
    'Thu'       => 'Do',
    'Fri'       => 'Fr',
    'Sat'       => 'Sa',
    'Sun'       => 'So',
    'January'   => 'Januar',
    'February'  => 'Februar',
    'March'     => 'März',
    'May'       => 'Mai',
    'June'      => 'Juni',
    'July'      => 'Juli',
    'October'   => 'Oktober',
    'December'  => 'Dezember'
);

$url = explode("/",$_SERVER['REQUEST_URI']);

/*
###################################################################
# Menü-Seite und Detailseiten aufbauen, wenn cache abgelaufen ist #
###################################################################
*/

if(isset($url[2])) {
	// In welcher Datei soll der Cache abgelegt werden?
	$feedcache_path = __DIR__.'/'.$url[1].$url[2].'.cache';

	#ist Cache noch aktuell?
	if(!file_exists($feedcache_path) or filemtime($feedcache_path) < (time() - $feedcache_max_age)) {
	  $xml = simplexml_load_string(file_get_contents($feed_url));
	  
	  $cls = chr(147); //clear screen
	  $head = $cls.$headline1.chr(18).c64encode($xml->channel->title).chr(146).$fontcolor1.chr(13).chr(13);

	  $entries = $xml->channel->item;
	  $counter = 0;
	  $page = 0;
	  
	  foreach($entries as $root) {
		  
			$counter++;
			if($counter > $max_entries) {
			  break;
			}
			
			//Detailseiten speichern
			
			$datum = date('D d.m.Y H:i:s', strtotime($root->pubDate));
			$datum = strtr($datum, $trans);
			$datum = strtoupper($datum);
			
			$date_str = $headline1.chr(18).$datum.chr(146).$fontcolor1.chr(13).chr(13);
			$text = wordwrap(c64encode($root->title), 39 , chr(13), false);
			$title = $headline1.$text.$fontcolor1.chr(13).chr(13);
			
			$text = wordwrap(c64encode($root->description), 39 , chr(13), false);
			$seite = chr(13).chr(13).$headline1."SEITE: ".c64key($counter,$keycolor ,$fontcolor1)." (".$counter.")".$fontcolor1;
			$description = $text.chr(13).chr(13).$menukey." ".$pagekex." ".$infokex." ".$exitkey.$seite;
			
			
			file_put_contents(__DIR__.'/d'.$counter.'.cache', $date_str.$title.$description);
			
			//Menü erstellen
			if ( $counter%2 ) { // ungerade
				$color=$fontcolor1;
			}
			else { // gerade
				$color=$fontcolor2;
			}
			
			// Überschrift für die Menüseiten
			if( $counter==1 || $counter==6 || $counter==11 ){
				$page++; // Seite 
				$output = $head;
			}
			
			$text = wordwrap(c64encode($root->title), 37 , chr(13), false);
			$output .= c64key($counter,$keycolor ,$fontcolor1)." ".$color.$text.$fontcolor1.chr(13).chr(13);
			
			if($counter==5 || $counter==10 || $counter==15) { //Menüseiten Speichern
				$output .= chr(13).$pagekex." ".$infokex." ".$exitkey;
				if($counter==5){
					$seite = chr(13).chr(13).$headline1."SEITE 1/3".$fontcolor1;
				} else if ($counter==10){
					$seite = chr(13).chr(13).$headline1."SEITE 2/3".$fontcolor1;
				} else if ($counter==15){
					$seite = chr(13).chr(13).$headline1."SEITE 3/3".$fontcolor1;
				}

				file_put_contents(__DIR__.'/m'.$page.'.cache', $output.$seite);
			}
	  }
	} 
}
/*
################################################
# Menü-Seite und Detailseiten für C64 ausgeben #
################################################
*/

if(isset($url[2])) {

	if($url[1]=="d") { // D = Details
		preg_match("/\d+/", $url[2],$result);
		
		$file = __DIR__.'/d'.$result[0].'.cache';
		
		if(!file_exists($file)) {
			echo "Nachricht nicht gefunden!".chr(13).chr(13);
		} else {
			echo chr(147); #clear screen on C64
			echo file_get_contents($file);
		}		
	}

	if($url[1]=="m") { // M = Menu
		preg_match("/\d+/", $url[2],$result);
		
		$file = __DIR__.'/m'.$result[0].'.cache';
		
		if(!file_exists($file)) {
			echo "Menü nicht gefunden!".chr(13).chr(13);
		} else {
			echo chr(147); #clear screen on C64
			echo file_get_contents($file);
		}		
	}	

}
?>
