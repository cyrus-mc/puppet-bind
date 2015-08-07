# = Definition: bind::record
#
# Helper to create any record you want (but NOT MX, please refer to Bind::Mx)
#
# Arguments:
#  *$zone*:             Bind::Zone name
#  *$record_type*:      Resource record type
#  *$ptr_zone*:         PTR zone - optional
#  *$content_template*: Allows you to do your own template, letting you
#                       use your own hash_data content structure
#  *$hash_data:         Hash containing data, by default in this form:
#        {
#          <host>         => {
#            owner        => <owner>,
#            ttl          => <TTL> (optional),
#            record_class => <Class>, (optional - default IN)
#          },
#          <host>         => {
#            owner        => <owner>,
#            ttl          => <TTL> (optional),
#            ptr          => false, (optional, default to true)
#            record_class => <Class>, (optional - default IN)
#          },
#          ...
#        }
#
define bind::record (
  $zone,
  $hash_data,
  $record_type,
  $zone_dynamic     = false,
  $ensure           = present,
  $content          = undef,
  $content_template = undef,
  $ptr_zone         = undef,
) {

  validate_string($ensure)
  validate_re($ensure, ['present', 'absent'],
              "\$ensure must be either 'present' or 'absent', got '${ensure}'")

  validate_string($zone)
  validate_string($record_type)
  validate_string($ptr_zone)
  validate_hash($hash_data)
  validate_bool($zone_dynamic)

  if ($content_template and $content) {
    fail '$content and $content_template are mutually exclusive'
  }

  if($content_template){
    warning '$content_template is deprecated. Please use $content parameter.'
    validate_string($content_template)
    $record_content = template(content_template)
  }elsif($content){
    $record_content = $content
  }else{
    $record_content = template('bind/default-record.erb')
  }
  
  if $zone_dynamic {
    file_line { "${zone}.${record_type}.${name}":
      path   => "${bind::params::dynamic_directory}/${zone}.conf",
      line   => template('bind/default-record.erb'),
      notify => Service['bind9'],
    }
  } else {
    concat::fragment {"${zone}.${record_type}.${name}":
      ensure  => $ensure,
      target  => "${bind::params::pri_directory}/${zone}.conf",
      content => $record_content,
      notify  => Service [ 'bind9' ],
    }
  }

  # update serial number 
  exec { "updateSerial-${zone}.${record_type}.${name}":
    command     => "/bin/sed -i \"s/[[:digit:]]\+\s\+; serial/$(/bin/date '+%s') ; serial/\" ${bind::params::dynamic_directory}/${zone}.conf",
    refreshonly => true,
    subscribe   => File_line[ "${zone}.${record_type}.${name}" ],
    notify      => Service [ 'bind9' ],
  }
}
