<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.1" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:output method="html" />
        <xsl:variable name="title" select="/rss/channel/title"/>
        <xsl:variable name="self" select="/rss/channel/uri"/>
            <xsl:template match="/">
<html lang="en-gb">
    <head>
        <title><xsl:value-of select="$title"/> XML Feed</title>
        <link rel="stylesheet" href="/css.css"/>
    </head>
    <body>
    <div id="header"><a href="/">Neighbourhood Fix-It</a></div>
    <div id="wrapper"><div id="content">
        <xsl:apply-templates select="rss/channel"/>
    </div></div>

<h2 class="v">Navigation</h2>
<ul id="navigation">
<li><a href="/">Home</a></li>
<li><a href="/faq">Information</a></li>
<li><a href="/contact">Contact</a></li>
</ul>

<p id="footer">Built by <a href="http://www.mysociety.org/">mySociety</a>.
Using lots of <a href="http://www.ordnancesurvey.co.uk/">Ordnance Survey</a> data, under licence,
and some <a href="https://secure.mysociety.org/cvstrac/dir?d=mysociety/bci">clever</a> <a
href="https://secure.mysociety.org/cvstrac/dir?d=mysociety/services/TilMa">code</a>.</p>

</body>
</html>
            </xsl:template>

            <xsl:template match="channel">
                <div id="rss_box">
                    <h1>What is this page?</h1>
                    <p>This is an RSS feed from the Neighbourhood Fix-It website. RSS feeds allow you to stay up to date with the latest changes and additions to the site.
                    To subscribe to it, you will need a News Reader or other similar device.
		    <br/>
		    <a href="http://news.bbc.co.uk/1/hi/help/3223484.stm#whatisrss"><strong>Help</strong>, I don't know what a news reader is and still don't know what this is about (from the BBC).</a></p>
                </div>

                <p>Below is the latest content available from this feed,
                <a href="#" class="item"><img height="16" hspace="5" vspace="0" border="0" width="16" alt="RSS News feeds" src="/i/feed.gif" title="RSS News feeds" /><xsl:value-of select="$title"/></a>.</p>

		<div id="rss_items"><ul><xsl:apply-templates select="item"/></ul></div>
                <div id="rss_rhs">
                    <h2 style="margin:0">Subscribe to this feed</h2>
                    <p>You can subscribe to this RSS feed in a number of ways, including the following:</p>
                    <ul>
                        <li>Drag the orange RSS button into your News Reader</li>
                        <li>Drag the URL of the RSS feed into your News Reader</li>
                        <li>Cut and paste the URL of the RSS feed into your News Reader</li>
                    </ul>
                    <h3>One-click subscriptions</h3>
                    <p>If you use one of the following web-based News Readers, click on the appropriate button to subscribe to the RSS feed.</p>
		<a href="http://www.bloglines.com/sub/{uri}"><img height="18" width="91" vspace="3" border="0" alt="bloglines" src="http://newsimg.bbc.co.uk/shared/bsp/xsl/rss/img/bloglines.gif" /></a><br />
                    <a href="http://www.feedzilla.com/mini/default.asp?ref=bbc&amp;url={uri}"><img height="22" width="93" vspace="3" border="0" alt="feedzilla" src="http://newsimg.bbc.co.uk/shared/bsp/xsl/rss/img/feedzilla.gif" /></a><br />
                    <a href="http://add.my.yahoo.com/rss?url={uri}"><img height="17" width="91" vspace="3" border="0" alt="my yahoo" src="http://newsimg.bbc.co.uk/shared/bsp/xsl/rss/img/myyahoo.gif" /></a><br />
<a href="http://www.newsgator.com/ngs/subscriber/subext.aspx?url={uri}"><img height="17" width="91" vspace="3" border="0" alt="newsgator" src="http://newsimg.bbc.co.uk/shared/bsp/xsl/rss/img/newsgator.gif" /></a><br />
<a href="http://www.live.com/?add={uri}"><img height="17" width="91" vspace="3" border="0" alt="Microsoft Live" src="http://newsimg.bbc.co.uk/shared/bsp/xsl/rss/img/windowslive.gif" /></a><br />

<ul>
<li><a href="http://google.com/reader/view/feed/{uri}">Google Reader</a></li>
<li><a href="http://my.msn.com/addtomymsn.armx?id=rss&amp;ut={uri}&amp;tt=CENTRALDIRECTORY&amp;ru=http://rss.msn.com">My MSN</a></li>
<li><a href="http://127.0.0.1:5335/system/pages/subscriptions?url={uri}">Userland</a></li>
<li><a href="http://127.0.0.1:8888/index.html?add_url={uri}">Amphetadesk</a></li>
<li><a href="http://www.feedmarker.com/admin.php?do=add_feed&amp;url={uri}">Feedmarker</a></li>
</ul>

                                </div>

        </xsl:template>

        <xsl:template match="item">
            <li>
               <a href="{link}" class="item"><xsl:value-of select="title"/></a><br/>
               <div><xsl:value-of select="description" /></div>
            </li>
        </xsl:template>

</xsl:stylesheet>
