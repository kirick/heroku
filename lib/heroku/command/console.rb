require "heroku/command/base"

# execute one-off console and rake commands
#
class Heroku::Command::Console < Heroku::Command::Base

  # rake COMMAND
  #
  # remotely execute a rake command
  #
  def rake
    app = extract_app
    cmd = args.join(' ')
    if cmd.length == 0
      display "Usage: heroku rake <command>"
    else
      heroku.start(app, "rake #{cmd}", :attached).each { |chunk| display(chunk, false) }
    end
  rescue Heroku::Client::AppCrashed => e
    error "Couldn't run rake\n#{e.message}"
  end

  # console [COMMAND]
  #
  # open a remote console session
  #
  # if COMMAND is specified, run the command and exit
  #
  def console
    app = extract_app
    cmd = args.join(' ').strip
    if cmd.empty?
      console_session(app)
    else
      display heroku.console(app, cmd)
    end
  rescue RestClient::RequestTimeout
    error "Timed out. Long running requests are not supported on the console.\nPlease consider creating a rake task instead."
  rescue Heroku::Client::AppCrashed => e
    error e.message
  end

protected

  def console_history_dir
    FileUtils.mkdir_p(path = "#{home_directory}/.heroku/console_history")
    path
  end

  def console_session(app)
    heroku.console(app) do |console|
      console_history_read(app)

      display "Ruby console for #{app}.#{heroku.host}"
      while cmd = Readline.readline('>> ')
        unless cmd.nil? || cmd.strip.empty?
          console_history_add(app, cmd)
          break if cmd.downcase.strip == 'exit'
          display console.run(cmd)
        end
      end
    end
  end

  def console_history_file(app)
    "#{console_history_dir}/#{app}"
  end

  def console_history_read(app)
    history = File.read(console_history_file(app)).split("\n")
    if history.size > 50
      history = history[(history.size - 51),(history.size - 1)]
      File.open(console_history_file(app), "w") { |f| f.puts history.join("\n") }
    end
    history.each { |cmd| Readline::HISTORY.push(cmd) }
  rescue Errno::ENOENT
  rescue Exception => ex
    display "Error reading your console history: #{ex.message}"
    if confirm("Would you like to clear it? (y/N):")
      FileUtils.rm(console_history_file(app)) rescue nil
    end
  end

  def console_history_add(app, cmd)
    Readline::HISTORY.push(cmd)
    File.open(console_history_file(app), "a") { |f| f.puts cmd + "\n" }
  end
end


