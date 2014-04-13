#!/usr/bin/perl

use strict;
use warnings;
use 5.010;

use WWW::Mechanize;
use HTML::TreeBuilder::XPath;
use Config::Tiny;
use Data::Dumper;
use DBI;

my $base_url = 'http://www.rippingrecords.com/tickets.php?page=1';

my @gigs = ();
my $mech = WWW::Mechanize->new();
our $config = Config::Tiny->new;
$config = Config::Tiny->read('ripped.cfg') or die "Cannot open config file: $@";

while (1) {
  my $response = $mech->get($base_url);
  if ( !$@ && $response->is_success ) {
    my $tree = HTML::TreeBuilder::XPath->new;
    $tree->parse( $response->decoded_content );

    my @rows = $tree->findnodes('//tr[@class="altbg" or @class="regbg"]');
    add_to_gigs( \@gigs, \@rows );

    # Any more?
    my $next = $mech->find_link( text => 'Next' );
    if ( defined $next ) {
      $base_url = $next->url;
    }
    else {
      last;
    }
  }
}

my $first    = 1;
my $insert   = "INSERT INTO gigs ( date, artist, venue, price, extra ) VALUES ";
my @bindvars = ();
foreach my $gig (@gigs) {
  if ( !$first ) {
    $insert .= ", ";
  }
  $first = 0;
  $insert .= "( STR_TO_DATE( ?, '%d-%m-%Y' ), ?, ?, ?, ? )";
  push @bindvars,
    (
    $gig->{date},  $gig->{artist}, $gig->{venue},
    $gig->{price}, $gig->{extra}
    );
}

my $dbh = DBI->connect(
  $config->{database}->{uri}, $config->{database}->{user},
  $config->{database}->{pass}, { RaiseError => 1, }
) or die "Cannot connect to database";

my $sth = $dbh->prepare('TRUNCATE TABLE gigs');
$sth->execute() or die $DBI::errstr;

$sth = $dbh->prepare($insert);
$sth->execute(@bindvars) or die $DBI::errstr;
$dbh->disconnect;

sub add_to_gigs {
  my ( $gigs, $rows ) = @_;

  foreach my $row (@$rows) {
    my @children = $row->content_list;
    my $price    = $children[4]->as_text;
    $price =~ s/\xA3/&pound;/;

    my $extra = $children[5]->as_text;

    if ( $extra =~ /sold out/i ) {
      $extra = 'Sold out';
    }
    else {
      $extra = $children[5]->look_down( _tag => 'a', )->as_HTML;
      $extra =~ s/\/tickets/http:\/\/www.rippingrecords.com\/tickets/;
    }

    push @$gigs,
      {
      date   => $children[0]->as_text,
      artist => $children[1]->as_text,
      venue  => $children[2]->as_text . ', ' . $children[3]->as_text,
      price  => $price,
      extra  => $extra,
      };
  }
  return;
}
