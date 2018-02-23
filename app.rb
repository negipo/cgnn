#!/usr/bin/env ruby
require 'bundler'
Bundler.require

URL = 'http://dic.nicovideo.jp/a/%E3%82%A2%E3%82%A4%E3%83%89%E3%83%AB%E3%83%9E%E3%82%B9%E3%82%BF%E3%83%BC%20%E3%82%B7%E3%83%B3%E3%83%87%E3%83%AC%E3%83%A9%E3%82%AC%E3%83%BC%E3%83%AB%E3%82%BA%3A%E5%91%BC%E7%A7%B0%E8%A1%A8'
CACHE_FILE = '.cache'
CACHE_DB = '.cache.db'

def main
  if ENV['FETCH_AND_STORE']
    fetch_and_store
  else
    search(ARGV.shift)
  end
end

def search(query)
  rows = db.execute("select * from nicknames where caller like ?;", "%#{query}%")
  puts rows.map {|r| r.join("\t") }
end

def fetch_and_store
  doc = Nokogiri::HTML(body)
  tables = doc.xpath('//table[@style="width: 100%;"]')
  rows = []
  tables.each do |table|
    table.xpath('.//tr').each do |tr|
      th = tr.xpath('.//th')
      tds = tr.xpath('.//td')
      next if tds.empty?

      caller = th.text
      tds[0].text.split("\n").each do |nickname|
        rows << [caller, '自分', nickname.gsub(/[\s　]/, '')]
      end
      tds[1].text.split("\n").each do |nickname|
        rows << [caller, 'プロデューサー', nickname.gsub(/[\s　]/, '')]
      end
      tds[2].text.split(/\n/).each do |line|
        line.gsub!(/[\s　]/, '')
        next if line.empty?
        callee, nickname = line.split("→")
        rows << [caller, callee, nickname]
      end
    end
  end
  store(rows)
end

def db
  @db ||= SQLite3::Database.new(CACHE_DB)
end

def store(rows)
  db.execute <<-SQL
    drop table if exists nicknames;
  SQL
  db.execute <<-SQL
    create table nicknames (
      caller varchar(30),
      callee varchar(30),
      nickname varchar(30)
    );
  SQL

  rows.each do |caller, callee, nickname|
    db.execute("insert into nicknames (caller, callee, nickname) values (?, ?, ?);", [caller, callee, nickname])
  end
end

def body
  if File.exists?(CACHE_FILE)
    open(CACHE_FILE).read
  else
    body = Faraday.get(URL).body
    open(CACHE_FILE, 'w').write body
    body
  end
end

main
