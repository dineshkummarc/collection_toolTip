<?php
/**
* This balloon tooltip package and associated files not otherwise copyrighted are distributed under the MIT-style license:
* 
* http://opensource.org/licenses/mit-license.php
* 
* Copyright 
*
* 2007-2012 Sheldon McKay, Cold Spring Harbor Laboratory
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
* THE SOFTWARE.
* 
* This is a tag extension that uses the reserved tag <balloon> to add JavaScript ajax
* popup balloons.  See http://mckay.cshl.edu/wiki/MediaWiki_Balloon_Extension
* for documentation.
* 
* @ingroup Extensions
* @author Sheldon Mckay (mckays@cshl.edu)
* @version 0.5
* @link http://www.mediawiki.org/wiki/Extension:Balloons
*/
 
# To activate the extension, include it at the end from your LocalSettings.php
# with: require_once("extensions/balloons.php");
 
if ( defined( 'MW_SUPPORTS_PARSERFIRSTCALLINIT' ) ) {
        $wgHooks['ParserFirstCallInit'][] = 'wfBalloonTooltips';
} else {
        $wgExtensionFunctions[] = 'wfBalloonTooltips';
}
 
$wgHooks['OutputPageBeforeHTML'][] = 'addBalloonJavascript';
 
$wgExtensionCredits['parserhook'][] = array(
        'name'        => 'Balloons',
        'version'     => '0.4',
        'author'      => 'Sheldon McKay',
        'description' => 'Balloon tooltips for wiki pages',
        'url'         => 'http://www.mediawiki.org/wiki/Extension:Balloons'
);
 
function wfBalloonTooltips() {
        global $wgParser;
        $wgParser->setHook( 'balloon', 'renderBalloonSpan' );
        return true;
}
 
# render span element with
function renderBalloonSpan( $input, $args ) {
  $text   = $args['title'];

  # strip HTML from the text inside the <balloon> element,
  # except for image tags
  # remove tag contents first
  $input = preg_replace('/>[^<>]+</','><',$input);
  $input = strip_tags($input,'<img>');

  # be paranoid and remove any event handlers from image tags
  $input = preg_replace('/\bon[^=]+=\S+/i','',$input);  

  # escape quotes in balloon caption
  $text   = preg_replace('/\"/','\"',$text);
  $text   = preg_replace('/\'/',"\'",$text);
  
  $link   = isset($args['link'])   ? $args['link']   : '';
  $target = isset($args['target']) ? $args['target'] : '';
  $sticky = isset($args['sticky']) ? $args['sticky'] : '0';
  $width  = isset($args['width'])  ? $args['width']  : '0';

  $event  = isset($args['click']) && $args['click'] && !$link ? 'onclick' : 'onmouseover';
  $event  = "$event=\"balloon.showTooltip(event,'${text}',${sticky},${width})\"";
  $event2 = ' ';

  if (preg_match('/onclick/',$event) && $args['hover']) {
    $event2 = " onmouseover=\"balloon.showTooltip(event,'" . $args['hover'] . "',0,${width})\"";
  }

  $has_style = isset($args['style']) && $args['style'];
  $style  = "style=\"" . ($has_style ? $args['style'] . ";cursor:pointer\"" : "cursor:pointer\"");
  $target = $target ? "target=${target}" : '';
  $output = "<span ${event} ${event2} ${style}>${input}</span>";
  
  if ($link) {
    $output = "<a href=\"${link}\" ${target}>${output}</a>";
  }
  
  return $output;
}
 
function addBalloonJavascript(&$out) {
  global $wgScriptPath;
  $jsPath = "${wgScriptPath}/extensions/balloons/js";

  $out->addScript("\n".
                  "<script type=\"text/javascript\" src=\"${jsPath}/prototype.js\"></script>\n" .
	          "<script type=\"text/javascript\" src=\"${jsPath}/balloon.config.js\"></script>\n" .
                  "<script type=\"text/javascript\" src=\"${jsPath}/balloon.js\"></script>\n" .
                  "<script type=\"text/javascript\">\n" .
                  "var balloon = new Balloon;\n" .
                  "balloon.images   = '${wgScriptPath}/extensions/balloons/images';\n" .
                  # Some skins need document.body as the parent, others use the 'content' layer
                  # Custom skin users/developers may need to edit the regular expression below
                  "balloon.parentID = skin.match(/simple|myskin|modern/) ? null : 'content';\n" .
                  "</script>\n"
		  );
  
  return true;
}

