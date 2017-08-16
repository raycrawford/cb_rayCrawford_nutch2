#
# Cookbook:: cb_rayCrawford_nutch2
# Recipe:: default
#
# Copyright:: 2017, Ray Craford, All Rights Reserved.

include_recipe 'cb_dvo_java::default'

package 'unzip' do
  action :install
end

package 'ant' do
    action :install
end

package 'lsof' do
  action :install
end

group 'solr' do
  action :create
end

user 'solr' do
  comment 'Apache Solr user account'
  group 'solr'
  home '/opt/solr'
  shell '/bin/bash'
  password '$6$toglYgWr$/8voBW54ru5W77TaYRDQbzFWr9vrdg4KAIxZTXbKyBIs4cOofu4Xz0DGmgXC.EgnQZ6SIKhhjZWuzjy2LFxiO/'
end

# Install solr
directory '/opt/solr' do
  owner 'solr'
  group 'solr'
  mode '0755'
  action :create
end

remote_file 'solr' do
  source 'http://apache.claz.org/lucene/solr/6.6.0/solr-6.6.0.tgz'
  path "#{Chef::Config[:file_cache_path]}/solr-6.6.0.tgz"
  owner 'root'
  group 'root'
  mode '644'
  action :create
end

bash 'Extract Solr' do
  cwd "#{Chef::Config[:file_cache_path]}"
  code <<-EOH
    cd #{Chef::Config[:file_cache_path]}
    tar xvf ./solr-6.6.0.tgz
    mv ./solr-6.6.0/* /opt/solr
    chown -R solr:solr /opt/solr
  EOH
  not_if { ::File.directory?('/opt/solr/bin') }
end

%w(startSolr.bash stopSolr.bash).each do |this_file|
  cookbook_file "/opt/solr/#{this_file}" do
    source "/opt/solr/#{this_file}"
    mode '0750'
    owner 'solr'
    group 'solr'
  end
end

systemd_unit 'solr.service' do
  content <<-EOH.gsub(/^\s+/, '')
    [Unit]
    Description=Solr service
    After=syslog.target network.target remote-fs.target nss-lookup.target systemd-journald-dev-log.socket
    Before=multi-user.target graphical.target nginx.service
    Conflicts=shutdown.target

    [Service]
    Type=simple
    RemainAfterExit=yes
    User=solr
    ExecStart=/opt/solr/bin/solr start
    PrivateTmp=true

    [Install]
    WantedBy=multi-user.target
  EOH
  action [:create, :enable]
  notifies :start, 'service[solr]', :immediately
end

service 'solr' do
  action :nothing
  notifies :run, 'ruby_block[sleep]', :immediately
end

ruby_block 'sleep' do
  block do
    sleep(15)
  end
  action :nothing
end

bash 'Create nutch Solr core' do
  cwd '/opt/solr'
  user 'solr'
  code <<-EOH
    /opt/solr/bin/solr create -c nutch
  EOH
  not_if { ::File.directory?('/opt/solr/server/solr/nutch')}
  notifies :restart, 'service[solr]', :immediately
end

# bash 'Copy solr schema' do
#   # per http://lucene.472066.n3.nabble.com/Nutch-2-Solr-5-solrdedup-causes-ClassCastException-td4301149.html
#   code <<-EOH
#     cp -rp /opt/solr/server/solr/configsets/data_driven_schema_configs/conf/* /opt/solr/server/solr/nutch/conf/
#   EOH
# end

# cookbook_file '/opt/solr/server/solr/nutch/conf/managed-schema' do
#   # per http://lucene.472066.n3.nabble.com/Nutch-2-Solr-5-solrdedup-causes-ClassCastException-td4301149.html
#   source '/opt/solr/server/solr/nutch/conf/solrconfig.xml'
#   mode '0644'
#   owner 'solr'
#   group 'solr'
#   notifies :restart, 'service[solr]', :delayed
# end

cookbook_file '/opt/solr/server/solr/nutch/conf/schema.xml' do
  source '/opt/solr/server/solr/nutch/conf/schema.xml'
  mode '0644'
  owner 'solr'
  group 'solr'
  notifies :restart, 'service[solr]', :delayed
end

cookbook_file '/opt/solr/server/solr/nutch/conf/schema.xml' do
  source '/opt/solr/server/solr/nutch/conf/schema.xml'
  mode '0644'
  owner 'solr'
  group 'solr'
  notifies :restart, 'service[solr]', :delayed
end

# Install hbase
%w(/opt/hbase /opt/hbase/data /opt/hbase/data).each do |new_directory|
  directory new_directory.to_s do
    owner 'solr'
    group 'solr'
    mode '0755'
    action :create
  end
end

directory '/opt/hbase' do
  owner 'solr'
  group 'solr'
  mode '0755'
  action :create
end

remote_file 'nutch 2.3.1' do
  source 'http://apache.claz.org/nutch/2.3.1/apache-nutch-2.3.1-src.tar.gz'
  path "#{Chef::Config[:file_cache_path]}/apache-nutch-2.3.1-src.tar.gz"
  owner 'root'
  group 'root'
  mode '644'
  action :create
end

bash 'Extract nutch' do
  code <<-EOH
    mkdir /opt/nutch
    cd #{Chef::Config[:file_cache_path]}
    tar xvf ./apache-nutch-2.3.1-src.tar.gz
    mv #{Chef::Config[:file_cache_path]}/apache-nutch-2.3.1/* /opt/nutch/
    chown -R solr:solr /opt/nutch
  EOH
#  not_if { ::File.directory?("#{Chef::Config[:file_cache_path]}/apache-nutch-2.3.1") }
end

cookbook_file '/opt/nutch/conf/nutch-site.xml' do
  source '/opt/nutch/conf/nutch-site.xml'
  owner 'solr'
  group 'solr'
  mode 0755
end

cookbook_file '/opt/nutch/conf/gora.properties' do
  source '/opt/nutch/conf/gora.properties'
  owner 'solr'
  group 'solr'
  mode 0755
end

cookbook_file '/opt/nutch/ivy/ivy.xml' do
  source '/opt/nutch/ivy/ivy.xml'
  owner 'solr'
  group 'solr'
  mode 0755
end

remote_file 'hbase 0.98.8' do
  source 'http://archive.apache.org/dist/hbase/hbase-0.98.8/hbase-0.98.8-hadoop2-bin.tar.gz'
  path "#{Chef::Config[:file_cache_path]}/hbase-0.98.8-hadoop2-bin.tar.gz"
  owner 'solr'
  group 'solr'
  mode '644'
  action :create
end

bash 'Extract hbase' do
  code <<-EOH
    cd #{Chef::Config[:file_cache_path]}
    tar xvf ./hbase-0.98.8-hadoop2-bin.tar.gz
    mv #{Chef::Config[:file_cache_path]}/hbase-0.98.8-hadoop2/* /opt/hbase/
    chown -R solr:solr /opt/hbase
  EOH
#  not_if { ::File.directory?("#{Chef::Config[:file_cache_path]}/hbase-0.98.8-hadoop2") }
end

cookbook_file '/opt/hbase/conf/hbase-env.sh' do
  source '/opt/hbase/conf/hbase-env.sh'
  owner 'solr'
  group 'solr'
  mode 0755
end

cookbook_file '/opt/hbase/conf/hbase-site.xml' do
  source '/opt/hbase/conf/hbase-site.xml'
  owner 'solr'
  group 'solr'
  mode 0644
end

bash 'Build nutch' do 
  code <<-EOH
    cd /opt/nutch
    ant runtime
    chown -R solr:solr /opt/nutch
  EOH
end

# Doesn't stay running
# systemd_unit 'hbase.service' do
#   content <<-EOH.gsub(/^\s+/, '')
#     [Unit]
#     Description=hbase service
#     After=syslog.target network.target remote-fs.target nss-lookup.target systemd-journald-dev-log.socket
#     Before=multi-user.target graphical.target nginx.service
#     Conflicts=shutdown.target

#     [Service]
#     Type=simple
#     ExecStart=/opt/hbase/bin/start-hbase.sh
#     ExecStop=/opt/hbase/bin/stop-hbase.sh
#     PrivateTmp=yes
#     User=solr

#     [Install]
#     WantedBy=multi-user.target
#   EOH
#   action [:create, :enable, :start]
# end

# May need to incorporate JAVA_HOME...
bash 'Start hbase' do 
  user 'solr'
  code <<-EOH
    /opt/hbase/bin/start-hbase.sh
  EOH
end

# su - solr
# cd /opt/nutch/runtime/local/bin
# export JAVA_HOME='/etc/alternatives/jre_1.8.0'
# /opt/hbase/bin/start-hbase.sh
# mkdir urls
# echo "http://www.bidfta.com/" > /opt/nutch/runtime/local/bin/urls/seed.txt
# /opt/nutch/runtime/local/bin/nutch inject urls/seed.txt 
# /opt/nutch/runtime/local/bin/crawl ./urls nutch http://127.0.0.1:8983/solr/nutch 3
