require 'sinatra'
require 'sinatra/reloader'
require 'pg'
require 'pry'
require "fileutils"
require 'digest'

enable :sessions

client = PG::connect(
    :host => ENV.fetch("DB_HOST", "localhost"),
    :user => ENV.fetch("DB_USER","postgres"),
    :password => ENV.fetch("DB_PASSWORD",""),
    :dbname => ENV.fetch("DB_NAME")
)

get '/signup' do
    return erb :signup
end

post '/signup' do
    name = params[:name]
    email = params[:email]
    password = params[:password]
    profile_img = "default_user.png"
    password_digest = Digest::SHA512.hexdigest(password)
    client.exec_params("INSERT INTO users (name, email, password_digest, profile_img) VALUES ($1, $2, $3, $4)", [name, email, password_digest, profile_img])
    user = client.exec_params("SELECT * from users WHERE email = $1 AND password_digest = $2", [email, password_digest]).to_a.first
    session[:user] = user
    return redirect '/home'
end

get '/user' do
    @user = session[:user]
    # binding.pry
    return erb :user
end

post '/user_edit' do
    user_id = session[:user]['id']
    filename = params[:profile_img][:filename]
    tempfile = params[:profile_img][:tempfile]
    save_to = "./public/images/#{filename}"
    FileUtils.mv(tempfile, save_to)
    # binding.pry
    client.exec_params("UPDATE users SET profile_img = $1 WHERE id = $2",[filename, user_id])
    user = client.exec_params("SELECT * from users WHERE id = $1", [user_id]).to_a.first
    session[:user] = user
    # binding.pry
    redirect '/user'
end

get '/' do
    if session[:user].nil?
        return erb :login
    else
        redirect '/home'
    end
end

post '/login' do
    email = params[:email]
    password = params[:password]
    password_digest = Digest::SHA512.hexdigest(password)
    user = client.exec_params("SELECT * FROM users WHERE email = $1 AND password_digest = $2 LIMIT 1",[email, password_digest]).to_a.first
    if user.nil?
        return erb :login
    else
        session[:user] = user
        return redirect '/home'
    end
end

delete '/logout' do
    session[:user] = nil
    return redirect '/'
end

get '/home' do
    if session[:user].nil?
        return redirect '/'
    end
    @today = Date.today.to_s
    @user =  client.exec_params("SELECT * FROM users WHERE id = $1",[session[:user]['id']]).to_a.first
    @chats = client.exec_params("SELECT * FROM chats JOIN users ON chats.user_id = users.id ORDER BY chats.id DESC").to_a
    @schedules = client.exec_params("SELECT * FROM schedules ORDER BY date DESC").to_a
    # binding.irb
    return erb :home
end

post '/schedule_post' do
    subject = params[:subject]
    date = params[:date]
    session = params[:session]
    complement = params[:complement]
    client.exec_params("INSERT INTO schedules (subject, date, session, complement) VALUES ($1, $2, $3, $4)",[subject, date, session, complement])
    redirect '/home'
end

delete '/schedule_delete/:id' do
    client.exec_params("DELETE FROM schedules WHERE id =$1",[params[:id]])
    redirect '/home'
end

post '/chat_post' do
    user_id = session[:user]["id"]
    content = params[:content]
    client.exec_params("INSERT INTO chats (user_id, content) VALUES ($1, $2)",[user_id, content])
    redirect '/home'
end