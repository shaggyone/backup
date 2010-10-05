#!/bin/ruby
require 'date'
require 'fileutils'
require 'yaml'


class Backup
  def initialize
    @config = YAML.load(File.read("/etc/backup.yml"))

    @chown_user  = @config['chown_user'] || "backup"
    @chown_group = @config['chown_user'] || "backup"
    @mysql_user  = @config['mysql_user'] || "backup"
    @mysql_password =   @config['mysql_password'] || ""
    @backup_from_folders = @config['folders'] || {}
    @backup_to_folder = @config['backup_to'] || "/var/backups"
    @time_offset = (@config['time_offset'] || 4).to_i

    @mysql_databases = @config['mysql_databases']
    if @mysql_databases=='all' || @mysql_databases.blank? then
      @mysql_databases = list_databases
    end

    @now = DateTime.now + @time_offset/24.0
  end
  
  def backup_path(what)
    "#{@backup_to_folder}/#{@now.year}-#{@now.month}/#{what}/#{what}-#{@now.strftime('%Y%m%d-%H%M%S')}.tar.gz"
  end

  def incremental_path(what)
    "#{@backup_to_folder}/#{@now.year}-#{@now.month}/#{what}/#{what}-#{@now.strftime('%Y%m01-000000')}.incremental"
  end

  def mysql_backup_path(db)
    "#{@backup_to_folder}/#{@now.year}-#{@now.month}/mysql/#{db}-#{@now.strftime('%Y%m%d-%H%M%S')}.sql.gz"
  end

  def exec(cmd, silent=false)
    puts cmd unless silent
    ret = `#{cmd}`
    puts ret unless silent
    ret
  end

  def mysql_backup(db)
    backup_to = mysql_backup_path(db)
    FileUtils.mkpath [File.dirname(backup_to)]    
    cmd = "mysqldump -u #{@mysql_user} -p#{@mysql_password} #{db} | gzip -9 > #{backup_to}" 
    exec cmd, true
  end

  def list_databases
    cmd = "mysql -u #{@mysql_user} -p#{@mysql_password} -Bse 'show databases'"
    exec(cmd, true).split("\n").map{|db| db.strip}
  end

  def backup_folder(from, what)
    Dir.chdir from do
      backup_to = backup_path(what)
      incremental = incremental_path(what)
      FileUtils.mkpath [File.dirname(backup_to), File.dirname(incremental)]
      exec "tar -cz --file=#{backup_to} --listed-incremental=#{incremental} ."
      FileUtils.chown @chown_user, @chown_group, [backup_to, incremental]
    end
  end

  def run
    @mysql_databases.each do |db|
      mysql_backup db
    end

    @backup_from_folders.each do |from, what|
      backup_folder from, what
    end
  end
end

Backup.new.run
