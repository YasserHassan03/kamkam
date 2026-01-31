import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { JWT } from "npm:google-auth-library@9"

Deno.serve(async (req) => {
  try {
    const payload = await req.json()
    console.log('Notification webhook triggered:', payload)

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    let notificationTitle = ''
    let notificationBody = ''
    let tournamentId = ''
    let homeTeamId = ''
    let awayTeamId = ''
    let matchId = ''

    const { record, table, type, old_record } = payload

    // --- LOGIC 1: GOALS ---
    if (table === 'match_events' && type === 'INSERT' && record.event_type === 'goal') {
      const { data: match } = await supabase
        .from('matches')
        .select('*, home_team:home_team_id(name), away_team:away_team_id(name)')
        .eq('id', record.match_id)
        .single()

      if (!match) throw new Error('Match not found')

      notificationTitle = 'GGGOOOAAALLL!!! ⚽'
      notificationBody = `${match.home_team.name} ${match.home_goals} - ${match.away_goals} ${match.away_team.name}`
      tournamentId = match.tournament_id
      homeTeamId = match.home_team_id
      awayTeamId = match.away_team_id
      matchId = match.id
    }

    // --- LOGIC 2: KICKOFF, FULL TIME & RESCHEDULE ---
    else if (table === 'matches' && type === 'UPDATE') {
      const { data: match } = await supabase
        .from('matches')
        .select('*, home_team:home_team_id(name), away_team:away_team_id(name)')
        .eq('id', record.id)
        .single()

      if (!match) throw new Error('Match not found')

      // Kickoff: scheduled -> in_progress
      if (old_record.status === 'scheduled' && record.status === 'in_progress') {
        notificationTitle = 'KICK OFF! ⚔️'
        notificationBody = `${match.home_team.name} vs ${match.away_team.name} has started!`
      }
      // Full time: in_progress -> finished
      else if (old_record.status === 'in_progress' && record.status === 'finished') {
        notificationTitle = 'FULL TIME 🏁'
        notificationBody = `Finished: ${match.home_team.name} ${record.home_goals} - ${record.away_goals} ${match.away_team.name}`
      }
      // Rescheduled: kickoff_time changed
      else if (old_record.kickoff_time !== record.kickoff_time) {
        const newTime = new Date(record.kickoff_time).toLocaleString('en-GB', {
          day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit'
        })
        notificationTitle = 'SCHEDULE UPDATE 📅'
        notificationBody = `${match.home_team.name} vs ${match.away_team.name} has been moved to ${newTime}`
      }
      else {
        return new Response(JSON.stringify({ message: 'Ignored match update' }), { status: 200 })
      }

      tournamentId = match.tournament_id
      homeTeamId = match.home_team_id
      awayTeamId = match.away_team_id
      matchId = match.id
    }

    // --- LOGIC 3: REMINDERS ---
    else if (payload.type === 'reminder') {
      const { data: match } = await supabase
        .from('matches')
        .select('*, home_team:home_team_id(name), away_team:away_team_id(name)')
        .eq('id', payload.match_id)
        .single()

      if (!match) throw new Error('Match not found')

      notificationTitle = 'MATCH STARTING SOON! 🔔'
      notificationBody = `${match.home_team.name} vs ${match.away_team.name} starts in 1 hour!`
      tournamentId = match.tournament_id
      homeTeamId = match.home_team_id
      awayTeamId = match.away_team_id
      matchId = match.id
    }

    if (!notificationTitle) {
      console.log('Skipping: No notification title set for this update.')
      return new Response(JSON.stringify({ message: 'No notification to send' }), { status: 200 })
    }

    console.log(`Payload ready: "${notificationTitle}" - "${notificationBody}"`)

    // Find all subscribed tokens
    console.log(`Querying subscribers for Tournament: ${tournamentId} OR Teams: ${homeTeamId}, ${awayTeamId}`)
    const { data: subscriptions, error: subError } = await supabase
      .from('user_subscriptions')
      .select('fcm_token')
      .or(`tournament_id.eq.${tournamentId},team_id.eq.${homeTeamId},team_id.eq.${awayTeamId}`)

    if (subError) {
      console.error('Subscription query error:', subError)
      throw subError
    }

    const tokens = [...new Set(subscriptions?.map(s => s.fcm_token) || [])]
    console.log(`Found ${tokens.length} unique subscriber tokens.`)

    if (tokens.length === 0) {
      return new Response(JSON.stringify({ message: 'No subscribers found' }), { status: 200 })
    }

    // Send to FCM
    const serviceAccount = JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT') || '{}')
    const privateKey = serviceAccount.private_key?.replace(/\\n/g, '\n')

    if (!privateKey) throw new Error('FCM_SERVICE_ACCOUNT private_key is missing')

    const jwtClient = new JWT(
      serviceAccount.client_email,
      undefined,
      privateKey,
      ['https://www.googleapis.com/auth/cloud-platform']
    )

    console.log('Fetching Google Access Token...')
    const { token: accessToken } = await jwtClient.getAccessToken()
    console.log('Access Token acquired.')

    const results = await Promise.all(tokens.map(async (token) => {
      try {
        console.log(`Attempting send to token: ${token.substring(0, 10)}...`)
        const response = await fetch(`https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${accessToken}` },
          body: JSON.stringify({
            message: {
              token: token,
              notification: { title: notificationTitle, body: notificationBody },
              data: { matchId: String(matchId), type: 'update' },
              android: { priority: 'high', notification: { sound: 'default', channel_id: 'high_importance_channel' } },
              apns: { payload: { aps: { sound: 'default', badge: 1 } } }
            },
          }),
        })

        const resData = await response.json()
        if (response.ok) {
          console.log(`Successfully sent to ${token.substring(0, 10)}...`)
          return true
        } else {
          console.error(`FCM Error for ${token.substring(0, 10)}...:`, resData)
          return false
        }
      } catch (e) {
        console.error(`Fetch error for ${token.substring(0, 10)}...:`, e)
        return false;
      }
    }))

    const sentCount = results.filter(Boolean).length
    console.log(`Finished. Total successfully sent: ${sentCount}/${tokens.length}`)

    return new Response(JSON.stringify({ success: true, sent: sentCount }), {
      headers: { 'Content-Type': 'application/json' },
    })

  } catch (err) {
    console.error('CRITICAL ERROR:', err)
    return new Response(JSON.stringify({ error: err.message }), { status: 500 })
  }
})
