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
    <div id="header"><a href="/">FixMyStreet</a></div>
    <div id="wrapper"><div id="content">
        <xsl:apply-templates select="rss/channel"/>
    </div></div>

<h2 class="v">Navigation</h2>
<ul id="navigation">
<li><a href="/">Report a problem</a></li>
<li><a href="/reports">All reports</a></li>
<li><a href="/faq">Help</a></li>
<li><a href="/contact">Contact</a></li>
</ul>

<p id="footer">Built by <a href="http://www.mysociety.org/">mySociety</a>,
using some <a href="https://secure.mysociety.org/cvstrac/dir?d=mysociety/bci">clever</a> <a
href="https://secure.mysociety.org/cvstrac/dir?d=mysociety/services/TilMa">code</a>.</p>

</body>
</html>
            </xsl:template>

            <xsl:template match="channel">
                <div id="rss_box">
                    <h1>What is this page?</h1>
                    <p>This is an RSS feed from the FixMyStreet website. RSS feeds allow you to stay up to date with the latest changes and additions to the site.
                    To subscribe to it, you will need a News Reader or other similar device.
                    <br/>
                    <a href="http://news.bbc.co.uk/1/hi/help/3223484.stm#whatisrss"><strong>Help</strong>, I don't know what a news reader is and still don't know what this is about <small>(from the BBC)</small>.</a></p>
                </div>

                <p>Below is the latest content available from this feed,
                <a href="#" class="item"><img height="16" hspace="5" vspace="0" border="0" width="16" alt="RSS News feeds" src="/i/feed.png" title="RSS News feeds" /><xsl:value-of select="$title"/></a>.</p>

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
<a href="http://www.bloglines.com/sub/{uri}"><img height="18" width="91" hspace="3" vspace="3" border="0" alt="bloglines" src="http://newsimg.bbc.co.uk/shared/bsp/xsl/rss/img/bloglines.gif" /></a>
<a href="http://www.feedzilla.com/mini/default.asp?ref=bbc&amp;url={uri}"><img height="22" width="93" hspace="3" vspace="3" border="0" alt="feedzilla" src="http://newsimg.bbc.co.uk/shared/bsp/xsl/rss/img/feedzilla.gif" /></a>
<a href="http://add.my.yahoo.com/rss?url={uri}"><img height="17" width="91" hspace="3" vspace="3" border="0" alt="my yahoo" src="http://newsimg.bbc.co.uk/shared/bsp/xsl/rss/img/myyahoo.gif" /></a>
<a href="http://www.newsgator.com/ngs/subscriber/subext.aspx?url={uri}"><img height="17" width="91" hspace="3" vspace="3" border="0" alt="newsgator" src="http://newsimg.bbc.co.uk/shared/bsp/xsl/rss/img/newsgator.gif" /></a>
<a href="http://www.live.com/?add={uri}"><img height="17" width="91" hspace="3" vspace="3" border="0" alt="Microsoft Live" src="http://newsimg.bbc.co.uk/shared/bsp/xsl/rss/img/windowslive.gif" /></a>
<a href="http://feeds.my.aol.com/add.jsp?url={uri}"><img hspace="3" src="http://o.aolcdn.com/myfeeds/html/vis/myaol_cta1.gif" alt="Add to My AOL" border="0"/></a>
<a href="http://www.rojo.com/add-subscription?resource={uri}"><img hspace="3" src="http://www.rojo.com/corporate/images/add-to-rojo.gif" alt="Subscribe in Rojo"/></a>
<a href="http://www.netvibes.com/subscribe.php?url={uri}"><img hspace="3" src="http://www.netvibes.com/img/add2netvibes.gif" alt="Add to netvibes" /></a>
<a href="http://fusion.google.com/add?feedurl={uri}"><img hspace="3" src="http://buttons.googlesyndication.com/fusion/add.gif" width="104" height="17" alt="Add to Google"/></a>
<a href="http://www.pageflakes.com/subscribe.aspx?url={uri}"><img hspace="3" src="http://www.pageflakes.com/subscribe2.gif" border="0"/></a>

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
               <div><xsl:value-of disable-output-escaping="yes" select="description" /></div>
            </li>
        </xsl:template>

</xsl:stylesheet>
