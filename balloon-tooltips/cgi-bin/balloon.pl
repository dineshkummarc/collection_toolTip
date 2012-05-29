#!/usr/bin/perl -w
# a CGI script to draw all kinds of fancy tooltip balloons
#
#$Id: balloon.pl,v 1.10 2008/06/20 14:07:48 sheldon_mckay Exp $
# Sheldon McKay <mckays@cshl.edu>

use strict;
use GD;
use CGI ':standard';
use CGI::Carp 'fatalsToBrowser';
use CGI::Pretty;
use Graphics::ColorNames qw/hex2tuple tuple2hex/;
use Digest::MD5 'md5_hex';
use File::Copy;

# Implementor NOTE: Ensure that a copy of the close button
# (available at http://mckay.cshl.edu/images/balloons/close.png)
# exists
use constant IMG_CACHE    => '/images/balloons/temp/';
use constant CLOSE_BUTTON => '/home/smckay/www/html/images/balloons/close.png';


use vars qw/$tarball @images $id $js_path $relative_url $unique_id/;

$unique_id = md5_hex(url(-query_string => 1));
$id        = param('image_name') || "b$$";

-d "$ENV{DOCUMENT_ROOT}/" . IMG_CACHE
    || die 'Temporary image directory does not exist: ' . IMG_CACHE . "\n";

system "rm -fr $ENV{DOCUMENT_ROOT}/" . IMG_CACHE . "${unique_id}*";

# color name lookup table
tie my %name2hex, 'Graphics::ColorNames', 'X';
my %hex2name = reverse %name2hex;

my $justdraw = param('justdraw');
my $doall    = param('doall') unless param('sample') || param('just_draw');
my $width    = param('width') || param('w') || 200;
my $height   = param('height') || param('h') || int( 2 * $width / 3 );
my $line     = param('line') || param('l') || 1;
my $theight  = param('theight') || param('th') || 40;
my $twidth   = param('twidth') || param('tw') || 60;
my $vpos     = param('vpos') || param('vp') || 'up';              # or 'down'
my $hpos     = param('hpos') || param('hp') || 'left';            # or 'right'
my $arc_r    = param('corners') || param('c') || 'round';
my $bgc      = param('bgcolor') || param('bg') || 'white';
my $fgc      = param('fgcolor') || param('fg') || 'black';
my $bcc      = param('balloon_color') || param('bc') || 'white';
my $shadow   = param('shadow') || param('s');
my $slice    = param('slice') || param('sl') || '';
my $connector_slice_height = param('connector_slice_height') || param('cslh');
my $body_slice_height      = param('body_slice_height') || param('bslh');
my %triangles;

if ($doall) {
  $width = $height = 1000;
  if ($shadow) {
    $_ -= 24 for ( $width, $height );
  }
}

# not caching anymore
my $exists = 0;

# deal with how round the corners should be
my %corners = (
  'square'    => 0,
  'round'     => 20,
  'rounder'   => 40
	       );

my $arc_dia = $corners{$arc_r};
my $arc = int($arc_dia/2 + 0.5); 

# some spillage issues if the balloon is not tall enough
if ( $height < 150 && $arc_dia > $height / 2 ) {
  $arc_dia = 20;
}

# minimum width/height ratio
if ( $width / $height >= 3 ) {
  $height = int( $width / 3 );
}

my ( $img, $fg, $bg, $bc, @rgb );
if (param()) {
  my $true_color = 1;
  $img = GD::Image->new( $width, $height, $true_color );

  # Convert named or RGB hex colors to GD indices
  $fg = color_index( $img, $fgc );
  $bg = color_index( $img, $bgc );
  $bc = color_index( $img, $bcc ); 

  $img->fill( 0, 0, $bg );

  $img->setThickness($line);
  $img->setAntiAliased($fg);

  my ( $x1, $x2, $x3, $x4, $y1, $y2 );
  if ( $arc_dia < $height ) {

    # top side
    $arc = int( $arc_dia / 2 + 0.5 );
    $x1  = $arc ? $arc - 1 : 0;
    $y1  = 0;
    $x2  = $width - $arc;
    $x2 += 1 if $arc;
    $y2  = $y1;
    $img->line( $x1, $y1, $x2, $y2, $fg );

    # top right corner
    $x1 = $width - $arc;
    $y1 = $arc;
    $y1-- if $arc;
    $img->arc( $x1, $y1, $arc_dia, $arc_dia, 271, 359, $fg ) if $arc;

    # right side
    $x1 = $width - 1;
    $y1 = $arc;
    $x2 = $x1;
    $y2 = $height - $arc;
    $img->line( $x1, $y1, $x2, $y2, $fg );

    # bottom right corner
    $x1 = $width - $arc;
    $y1 = $height - $arc;
    $img->arc( $x1, $y1, $arc_dia, $arc_dia, 1, 89, $fg );

    # bottom side
    $x2 = $arc ? $arc - 1 : 1;
    $y1 = $height - 1;
    $y2 = $y1;
    $img->line( $x1, $y1, $x2, $y2, $fg );

    # bottom left corner
    $x1 = $arc;
    $y1 = $height - $arc;
    $img->arc( $x1, $y1, $arc_dia, $arc_dia, 91, 179, $fg );

    # left side
    $x1 = $arc ? 1 : 0;
    $y1 = $arc;
    $x2 = $x1;
    $y2 = $height - $arc - 1;
    $img->line( $x1, $y1, $x2, $y2, $fg );

    # top left corner
    $x1 = $arc;
    $y1 = $arc;
    $y1-- if $arc;
    $img->arc( $x1, $y1, $arc_dia, $arc_dia, 181, 269, $fg );
  }

  # I guess it could happen
  else {
    $arc_dia = $height;
    ($arc) = sort { $b <=> $a } int( $arc_dia / 2 + 0.5 ), int( $width / 4 );
    $x1 = $arc;
    $y1 = 0;
    $x2 = $width - $arc + 1;
    $y2 = $y1;
    $img->line( $x1, $y1, $x2, $y2, $fg );

    $x1 = $width - $arc;
    $y1 = int( $height / 2 + 0.5 );
    $img->arc( $x1, $y1, $height, $height, 271, 89, $fg );

    $x1 = $arc - 1;
    $img->arc( $x1, $y1, $height, $height, 91, 270, $fg );
  }

  $img->fill( int( $width / 2 ), int( $height / 2 ), $bc );
  add_background();
  add_shadow() if $shadow;

  # Draw the stems
  $triangles{upright} = GD::Image->new( $twidth, $theight, $true_color );
  my $t_fg    = color_index( $triangles{upright}, $fgc );
  my $t_bg    = color_index( $triangles{upright}, $bcc );
  my $t_trans = color_index( $triangles{upright}, 'orange');
  $triangles{upright}->fill( 1, 1, $t_bg );

  $x1 = 0;
  $x2 = int( $twidth / 2 + 0.5 );
  $y1 = $theight;
  $y2 = 0;
  $triangles{upright}->line( $x1, $y1, $x2, $y2, $t_fg );

  $x2 = $twidth;
  $triangles{upright}->line( $x1, $y1, $x2, $y2, $t_fg );
  $triangles{upright}->line( $x1, $y1, $x2, $y2, $t_fg );

  #$x1 = $twidth - 5;
  #$y1 = 0;
  #$triangles{upright}->fill( $x1, $y1, $t_bg );

  $x1 = 0;
  $y1 = 0;
  $triangles{upright}->fillToBorder( $x1, $y1, $fg, $t_trans );

  $x1 = $twidth-2;
  $y1 = $theight-2;
  $triangles{upright}->fillToBorder( $x1, $y1, $fg, $t_trans );

  # we need all four orientations
  $triangles{upright}->transparent($t_trans);
  $triangles{upleft} = $triangles{upright}->copyFlipHorizontal();
  $triangles{upleft}->transparent($t_trans);
  $triangles{downright} = $triangles{upright}->copyFlipVertical();
  $triangles{downright}->transparent($t_trans);
  $triangles{downleft} = $triangles{upleft}->copyFlipVertical();
  $triangles{downleft}->transparent($t_trans);
  

  # There is some dark magic here.  I do not know why but
  # this otherwise futile copy operation somehow fixes 
  # transparency in IE6.
  for (qw/upright upleft downright downleft/) {
    my $new = GD::Image->new($twidth,$theight);
    my $r = color_index($new,'red');
    $new->transparent($r);
    $new->fill(0,0,$r);
    $new->copy($triangles{$_},0,0,0,0,$twidth,$theight);
    $triangles{$_} = $new;
  }


  # add the triangle to the balloon if this is a sample image
  add_stem() unless $doall || $justdraw;

  @images = generate_image();
}

do_form();

exit 0;

# Just draw one
sub generate_image {
  $relative_url = param('image_url')  || "/images/balloons";
  $relative_url =~ s/\/$//;
  $relative_url = "/$relative_url" unless $relative_url =~ m!^/!;
  $js_path .="$relative_url/$id";
  my $name = "$unique_id.png";

  my @images;

  my $web_name = IMG_CACHE . $name;
  my $sys_name = $ENV{DOCUMENT_ROOT} . "/$web_name";

  make_png( $img, $sys_name);

  # make a tarball to facilitate download of all balloon parts
  if ($doall) {
    @images = generate_all_images($id);
    my $path = $ENV{DOCUMENT_ROOT} . IMG_CACHE;
    chdir $path or die $!;
    copy(CLOSE_BUTTON, $id);
    system "tar czf $id.tar.gz $id/*";
    $tarball = IMG_CACHE . "$id.tar.gz";
  }

  if ($justdraw) {
    print "Location: $web_name\n\n";
    exit;
  }

  return $web_name, @images;
}

sub make_png {
  my ( $gd, $sys_name ) = @_;
  
  open PNG, ">$sys_name" or die $!;
  binmode PNG;
  print PNG $gd->png;
  close PNG or die $!;
  
  if (-d $id) {
    unlink($id) || die $!;
  }

  # staging for tarball -- don't need ugly unique names
  my $new_name = $sys_name;
  $new_name =~ s/\S+\/(\S+)$/$1/;
  $new_name =~ s/$unique_id\.png/balloon\.png/;
  $new_name =~ s/$unique_id\_//;

  my $image_path =  $ENV{DOCUMENT_ROOT} . IMG_CACHE . $id;
  mkdir($image_path) or die $! unless -d $image_path;

  unlink "$image_path/$new_name" if -e "$image_path/$new_name";
  copy($sys_name,"$image_path/$new_name") or die "$new_name $!";
}

# For the "Draw all" option
sub generate_all_images {
  my $url      = url;
  my $img_url  = IMG_CACHE . "${unique_id}.png";
  my $img_name = $ENV{DOCUMENT_ROOT} . "/$img_url";
  make_png($img,$img_name);
  my @images    = ($img_url);

  for my $v (qw/up down/) {
    for my $h (qw/left right/) {
      my $image_name = "${unique_id}_${v}_$h.png";
      my $web_name   = IMG_CACHE . $image_name;
      my $sys_name   = $ENV{DOCUMENT_ROOT} . "/$web_name";
      make_png( $triangles{ $v . $h }, $sys_name );
      push @images, $web_name;
    }
  }

  return @images;
}

sub add_background {
  my $orange = color_index( $img, 'orange' );
  $img->fillToBorder( 0,          0,           $fg, $orange );
  $img->fillToBorder( $width - 1, 0,           $fg, $orange );
  $img->fillToBorder( $width - 1, $height - 1, $fg, $orange );
  $img->fillToBorder( 0,          $height - 1, $fg, $orange );
  $img->transparent($orange);
}

sub add_shadow {
  my $base_image = GD::Image->new( $width + 24, $height + 24 );
  my $orange = color_index( $base_image, 'orange' );
  my $shadow_clr = color_index( $base_image, 'black', 90 );
  my $new_fg = color_index( $base_image, $fgc );
  $base_image->copy( $img, 24, 24, 0, 0, $width, $height );
  $base_image->fillToBorder( 0, 0, $new_fg, $orange );
  $base_image->fillToBorder(
    int( $width / 2 ),
    int( $height / 2 ),
    $orange, $shadow_clr
  );
  $base_image->copy( $img, 12, 12, 0, 0, $width, $height );
  $base_image->transparent($orange);
  $img = $base_image;
  $_ += 24 for ( $width, $height );
}

sub color_index {
  my $img   = shift;
  my $color = lc shift;
  my $alpha = shift;
  $color =~ s/\#//;
  my @rgb = hex2tuple( $name2hex{$color} || $color );
  my $rtn = $alpha
      ? $img->colorAllocateAlpha( @rgb, $alpha )
      : $img->colorResolve(@rgb);
  return wantarray ? ( $rtn, @rgb ) : $rtn;
}

sub do_form {
  print header,
      start_html( -title => 'draw a balloon', -bgcolor => 'lightcyan' );
  print h3('Tooltip balloons: Use this form to generate balloon images');
  print div (
    { -style =>
          "background-color:whitesmoke;width:80%;margin-left:20px;border:1px solid red"
    },
    ul(
      li(
        qq(This CGI script is designed to draw balloon images for use with ),
        qq(<a target="_new" href="http://www.gmod.org/wiki/Popup_Balloons">balloon.js</a>,),
        qq(a javaScript library for popup balloon tooltips)
      ),
      li(
        qq(Click on the "<font color=green><b>Draw Sample</b></font>" button for a sample of a ),
        qq(complete balloon),
      ),
      li(
        qq(Click on the "<font color=green><b>Draw All</b></font>" button for all the images ),
        qq(<a href="http://www.gmod.org/wiki/Popup_Balloons#Notes_on_balloon_images" target="_new">),
        qq(required by balloon.js</a>)
      ),
      li(
        qq(Please contact Sheldon McKay <a href="mailto:mckays\@cshl.edu">&lt;mckays\@cshl.edu&gt;</a> for more information)
      )
    )
      ),
      br, start_form( -name => 'f1', -method => 'POST' );

  if ( $doall ) {
    print hidden( -name => 'doall', value => 1 );
  }

  my @balloon_colors = 
      qw/ivory white lightsteelblue slateblue cyan whitesmoke 
      yellow grey violet green purple blue black gainsboro lightgrey silver powderblue/;
  my @outline_colors = reverse @balloon_colors;
  
  @balloon_colors = grep {!/$fgc/} @balloon_colors;
  @outline_colors = grep {!/$bcc/} @outline_colors;

  my @onchange = ( -onchange => "document.f1.submit()" );
  my $submit = submit(
    { -name    => 'sample',
      -onclick => 'document.f1.submit()',
      -value   => 'Draw Sample',
      -style   => "color:green;font-weight:bold"
    }
  );
  my $submit2 = submit(
    { -name  => 'doall',
      -value => 'Draw All',
      -style => "color:green;font-weight:bold"
    }
  );

  print table (
    { -cellspacing => 10, -width => '90%' },
    Tr(
      [ td(
          'Vertical orientation '
              . popup_menu(
            -name    => 'vp',
            -values  => [ qw/up down/ ],
            -default => $vpos,
            @onchange
              )
            )
            . td(
          'Horizontal orientation '
              . popup_menu(
            -name    => 'hp',
            -values  => [ qw/left right/ ],
            -default => $hpos,
            @onchange
              )
            )
            . td(
          'Outline color '
              . popup_menu(
            -name    => 'fg',
            -values  => \@outline_colors,
            -default => $fgc,
            @onchange
              )
            )
            . td(
          'Balloon color '
              . popup_menu(
            -name    => 'bc',
            -values  => \@balloon_colors,
            -default => $bcc,
            @onchange
              )
            ),
        td(
          'Corners '
              . popup_menu(
            -name    => 'c',
            -values  => [qw/square round rounder/],
            -default => $arc_r,
            @onchange
              )
            )
            . td(
          'Stem height '
              . textfield(
            -name => 'th',
            value => $theight,
            size  => 4,
            @onchange
              )
            )
            . td(
          'Stem width '
              . textfield(
            -name => 'tw',
            value => $twidth,
            size  => 4,
            @onchange
              )
            )
            . td(
          checkbox(
            -name   => 's',
            -label  => 'Shadow',
            checked => $shadow,
            @onchange
          )
            ),
        td(
          { -colspan => 2 },
          'Base name for balloon images: '
              . textfield(
            -name  => 'image_name',
            -value => "balloon$$",
            size   => 12
              )
            )
            . td(
          { -colspan => 2 },
          'Relative URL for balloon images: '
              . textfield(
            -name  => 'image_url',
            -value => "/images/balloons",
            size   => 20
              )
            )
      ]
    ),
    Tr(
      td(
        { -colspan => 4 }, $submit, '&nbsp;&nbsp;', $submit2,
        '&nbsp;&nbsp;', reset
      )
    )
  );

  print end_form, hr;

  my $web_name = shift @images;
  unless ( @images || !$web_name ) {
    print h2('Sample balloon');
    print i('NOTE: This is a sample image.<br>Click "Draw All" above to get all the required image components for balloon.js'),p; 
    print div (
      img(
        { -src   => $web_name,
          -style => "position:absolute;z-index:10;left:50px;margin-top:30px"
        }
      ),
      div(
        { -style =>
              "position:absolute;color:grey;width:40%;height:350px;overflow:hidden"
        },
        'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur eget augue a turpis auctor congue. Integer ut leo. Ut purus. Duis tortor enim, facilisis at, rhoncus vitae, egestas ullamcorper, lacus. Nulla cursus luctus magna. Proin at tellus et mauris porta eleifend. Morbi pharetra tincidunt velit. Nam tempor. Nulla facilisi. Nunc tincidunt. Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Sed metus velit, malesuada nec, sagittis vel, lobortis vel, augue. Morbi a erat in enim hendrerit tincidunt. In sed ipsum in mi elementum pretium. Duis elementum, mauris at congue consectetuer, dui nisl laoreet turpis, sed condimentum felis neque sed arcu. Suspendisse ut nulla ac leo volutpat consectetuer. Praesent vitae mi sed est suscipit convallis. Fusce ac enim et erat semper egestas. Nulla rutrum nulla.

Mauris volutpat, massa vitae pretium fringilla, massa elit malesuada orci, a vestibulum augue leo et mauris. Suspendisse molestie. Fusce hendrerit nulla ac dui. Proin tempor condimentum eros. Morbi quis risus ac ante pharetra volutpat. In hac habitasse platea dictumst. Donec sagittis augue mollis orci. In hac habitasse platea dictumst. Suspendisse tristique nibh ac massa. Donec porttitor laoreet velit. Aenean eleifend nulla eget risus tempus dignissim. Fusce et lacus. Sed adipiscing, arcu sed aliquet interdum, dolor est facilisis libero, vel suscipit orci neque et ipsum. Pellentesque ultrices.

Mauris tincidunt leo ac metus. Sed est. Vivamus sed enim a eros volutpat hendrerit. Donec lacinia dictum tellus. In congue, nisi et pellentesque consectetuer, sem est viverra risus, nec condimentum velit leo quis dui. Nullam quam lectus, ultricies in, tincidunt vitae, ultrices quis, orci. Suspendisse lectus. Quisque hendrerit pulvinar nunc. Nulla gravida malesuada purus. Sed iaculis.'
      )
    );
  }
  elsif (@images) {
    my $swidth = $shadow ? 12 : 0;
    $arc ||= 5;
    my $image_src = url(-query_string => 1);
    $image_src =~ s/doall/justdraw/;

    my @stems  = map { img( { -src => $_ } ) } grep {!/$unique_id\.png/} @images;
    my ($body) = grep { /$unique_id\.png/} @images;

 
    print  h2("How to use these images"),
    ol(
       li( a({href=> $tarball},'download the images') ),
       li(
	  "Unpack the file ($id.tar.gz) in your image directory (DOCUMENT_ROOT$relative_url)"),
       li(
	  "Insert the javascript code below into the &lt;head&gt; element, making sure the javascript and image paths are correct"
	  ),
       li(
	  "See the <a target='_new' href='http://www.gmod.org/wiki/Popup_Balloons'>",
	  "documentation</a> for more information on the balloon.js package"
	  )
       ),
       
       pre(
	   { -style => 'border:1px dashed black;background:white;padding:5px' },
	   qq( &lt;script type="text/javascript" src="/js/balloon_config.js"&gt;&lt;/script&gt;<br>),
	   qq(&lt;script type="text/javascript" src="/js/balloon.js"&gt;&lt;/script&gt;<br>),
	   qq(&lt;script type="text/javascript" src="/js/yahoo-dom-event.js"&gt;&lt;/script&gt;<br>),
	   qq(&lt;script type="text/javascript"&gt;<br>),
	   qq(  var $id             = new Balloon;<br>),
	   qq(  $id.padding         = $arc;<br>),
	   qq(  $id.shadow          = $swidth;<br>),
	   qq(  $id.stemHeight      = $theight;<br>),
	   qq(  $id.stemOverlap     = 1;<br>),
	   qq(  $id.images          = '$js_path';<br>),
	   qq(  $id.balloonImage    = 'balloon.png';<br>),
	   qq(  $id.upLeftStem      = 'up_left.png';<br>),
	   qq(  $id.upRightStem     = 'up_right.png';<br>),
	   qq(  $id.downLeftStem    = 'down_left.png';<br>),
	   qq(  $id.downRightStem   = 'down_right.png';<br>),
	   qq(  $id.closeButton     = 'close.png';<br>),
	   qq(  $id.ieImage         = null;<br>),
	   qq(&lt;/script&gt;<br>)
	   );
  }
}

sub add_stem {
  # Counterintuitive, I know.
  my $up    = $vpos eq 'down';
  my $right = $hpos eq 'left';

  my $zero = $shadow ? 12 : 0;
  my $stem = $triangles{ $vpos . $hpos };
  my ( $width, $height, $twidth, $theight )
      = ( $img->width, $img->height, $stem->width, $stem->height );
  my $composite_height = $height + $theight - 1;
  my $composite_image  = GD::Image->new( $width, $composite_height );

  my $orange = color_index( $composite_image, 'orange' );
  $composite_image->fill( 0, 0, $orange );
  $composite_image->transparent($orange);

  my $body_vstart = $up ? $composite_height - $height - 1 : $zero;
  my $stem_vstart = $up    ? $zero            : $composite_height - $theight;
  my $stem_hstart = $right ? $width - $twidth : $zero;
  $stem_hstart -= 12 if $shadow && $right;
  $composite_image->copy( $img, 0, $body_vstart, 0, 0, $width, $height );
  $composite_image->copy( $stem, $stem_hstart, $stem_vstart, 0, 0, $twidth,
    $theight );
  $img = $composite_image;
}
