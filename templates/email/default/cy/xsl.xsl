[%
email_footer = site_name;
-%]
[% FILTER collapse %][% PROCESS '_email_settings.html' %][% END ~%]
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.1" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:output method="html" />
    <xsl:variable name="title" select="/rss/channel/title"/>
    <xsl:variable name="uri" select="/rss/channel/uri"/>
    <xsl:template match="/">
        [% PROCESS '_email_top.html' for_rss=1 rss_title='<xsl:value-of select="$title"/> XML Feed' %]

        <th style="[% td_style %][% rss_meta_style %]">
            <p>
            Dyma ffrwd RSS o'r wefan [% site_name%]. Mae ffrydiau RSS yn eich galluogi
            i dderbyn y wybodaeth ddiweddaraf am y newidiadau a'r ychwanegiadau diweddaraf i'r wefan.
            <a href="https://www.bbc.co.uk/news/10628494">Dysgu mwy am ffrydiau RSS.</a>
            </p>
            <p>
            Er mwyn tanysgrifio i'r ffrwd RSS yma, copïwch yr URL hwn i'ch darllenydd ffrwd RSS:
            <input type="text" style="[% text_input_style %]" onClick="this.setSelectionRange(0, this.value.length)">
                <xsl:attribute name="value">
                    <xsl:value-of select="$uri"/>
                </xsl:attribute>
            </input>
            </p>
        </th>

    </tr>
    <tr>

        <th style="[% td_style %][% only_column_style %]">
            <h1 style="[% h1_style %]"><xsl:value-of select="$title"/></h1>
            <xsl:apply-templates select="rss/channel/item"/>
        </th>

        [% PROCESS '_email_bottom.html' %]

    </xsl:template>

    <xsl:template match="item">
        <div style="[% list_item_style %]">
            <h2 style="[% list_item_h2_style %]"><a href="{link}"><xsl:value-of select="title"/></a></h2>
            <xsl:value-of disable-output-escaping="yes" select="description" />
        </div>
    </xsl:template>

</xsl:stylesheet>
