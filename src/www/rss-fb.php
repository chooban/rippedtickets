<?
header("Content-Type: text/xml; charset=utf-8\n");
print '<?xml version="1.0" encoding="UTF-8"?>';
?>


<rss version="0.92">
<channel>
<title>Ripped Tickets</title>
<link>http://rippedtickets.info</link>
<description>Scottish gig listings from Ripping Records</description>
<lastBuildDate>Wed, 31 Jan 2007 12:52:40 +0000</lastBuildDate>
<language>en</language>
        
<?




EOR;
$dblink = mysql_connect("", "", "") or die("Could not connect: " . mysql_error());
mysql_select_db("ripped") or die("Could not select database");
$query = "SELECT * FROM gigs ORDER by date DESC, artist;";
$result = mysql_query($query) or die("Query failed: " . mysql_error());
while ($row = mysql_fetch_assoc($result))
{
print "<item>";
print("<title>".ereg_replace("&","&amp;",$row['artist'])."</title>");
print("<description><![CDATA[
".$row['artist']." @ ".$row['name']." (".$row['date'].") ".$row['price']." (".$row['extra'].")
]]></description>");
print "</item>";
}
mysql_close($dblink);

?>

</channel>
</rss>
