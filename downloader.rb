require "digest/md5"
require "rest-client"
require "json"
require 'open-uri'
require 'open-uri'


class Downloader
  def initialize(movie_path)
    @shooter_url = "http://www.shooter.cn/api/subapi.php"
    @movie_path = movie_path
    @movie_utf8_path = URI::encode(@movie_path.force_encoding("utf-8"))
    @block_size = 4096
    @@file =  File.open(@movie_path)
    @@file_length = @@file.size
  end

  def get_movie_fingerprint
    # get hash(encode with md5) of movie file
    # https://docs.google.com/document/d/1w5MCBO61rKQ6hI5m9laJLWse__yTYdRugpVyz4RzrmM/preview?pli=1
    # get file block from 4 parts of file, each block is 4096 byte
    # 4k from begining of the file
    # 1/3 of total file length
    # 2/3 of total file length
    # 8k from end of the file

    fingerprints = []
    unless @@file_length < 8192
      [4096,@@file_length/3*2,@@file_length/3, @@file_length-8192].each do |offset|
        @@file.seek offset
        fingerprints << Digest::MD5.hexdigest(@@file.read(@block_size))
      end
    else
      puts "get wrong file, a vedio should be larger than 8192"
    end
    fingerprint = URI::encode(fingerprints.join(';').force_encoding("utf-8"))
  end

  # search subtitle with shooter.cn API
  # https://docs.google.com/document/d/1ufdzy6jbornkXxsD-OGl3kgWa4P9WO5NZb6_QYZiGI0/preview?pli=1
  def search_subtitles(language="Chn", subtitle_format="srt")
    search_result = []
    data = {"filehash"=>get_movie_fingerprint,
            "pathinfo" => @movie_utf8_path,
            "format" => "json",
            "lang"=>language}
    index=1
    begin
    results = JSON.parse (RestClient.post @shooter_url,data).body  
    results.each do |r|
      r['Files'].each do |f|
        if f['Ext'] == subte_format
          sub_name = (@movie_path.split(".")[0..-2]<<index<<'srt').join(".")
          search_result << {"file" => sub_name, "url" => f['Link'].gsub('https:/','http:/')}
          index += 1
        end
      end
    end
    rescue Exception => e
      puts "Failed to search subtitle from shooter.cn"
      puts "get erros ------> #{e}"       
    end    
    search_result
  end

  # download file with wget
  def download_subtitles
    search_subtitles.each do |result|
      command = %Q(wget -O "#{result['file']}" "#{result['url']}")
      system command
    end
  end
end


path = "/Volumes/Macintosh HD/Movies/captain phillips.mkv"
Downloader.new(path).download_subtitles
