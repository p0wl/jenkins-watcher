# Description:
#   Fetches latest build of stable-ready-for-deploy and notifys users that are subscribed
#
# Commands:
#   hubot jek
#
# Author:
#   p0wl

module.exports = (robot) ->

  watcher = new JenkinsWatcher robot

  robot.respond /jenkins fetch/i, () ->
    watcher.fetchLastJob()

  robot.respond /jenkins watch (.*)/i, (msg) ->
    watcher.watchForUser msg.message.user.name, msg.match[1]

  robot.respond /jenkins watching/i, (msg) ->
    msg.send "[Jenkins-Watcher] Watching total of #{watcher.watching.length} revisions"

  robot.respond /jenkins start/i, (msg) ->
    watcher.fetchLastJob()
    msg.send "[Jenkins-Watcher] Started."

class JenkinsWatcher
  fetchurl: 'http://hudson/view/stable-pipeline/job/stable-ready-for-deploy/lastBuild/api/json'
  deployurl: 'http://hudson/view/stable-pipeline/'

  constructor: (robot) ->
    @robot = robot
    @watching = []

  watchForUser: (user, revision) ->
    @watching.push {'user': user, 'revision': revision}
    @robot.send user, "[Jenkins-Watcher] #{user} is getting notified when #{revision} is ready"
    if @watching.length == 1
      @restartTimer()

  fetchLastJob: () ->
    that = this
    req = @robot.http("#{@fetchurl}/api/json")
    req.get() (err, res, body) ->
      content = JSON.parse(body)
      build = that.extractFromContent(content)
      that.notifyUser build
      console.log("[Jenkins-Watcher] Fetched and notified for " + JSON.stringify(build) + "\n")
      that.restartTimer()

  notifyUser: (build) ->
    for ticket in @watching when ticket.revision == build.revision
      if (build.result == 'SUCCESS')
        @robot.send ticket.user, "[Jenkins-Watcher] You can now deploy #{ticket.revision}, stable-pipline: #{@deployurl}"
      else
        @robot.send ticket.user, "[Jenkins-Watcher] Your build of revision #{ticket.revision} FAILED! Status: #{build.result}. stable-pipline: #{@deployurl}"
      @watching = @watching.filter (x) ->
        x isnt ticket

  extractFromContent: (content) ->
    params = action.parameters for action in content.actions when action.parameters
    revision = param.value for param in params when param.name == 'GIT_COMMIT'
    return {'revision': revision, 'result': content.result, 'number': content.number}

  restartTimer: () ->
    if @watching.length
      that = this
      setTimeout (->
        that.fetchLastJob()
      ), 5000
    else
      console.log '[Jenkins-Watcher] Nothing to watch, going to sleep'