require! firebase
root = new firebase 'https://g0v-test.firebaseio.com/'

err <- root.auth 'O98nxxEJuihzV2uT8wSL1IgHO4g4BRjzkPXgoOMP'
throw err if err

z = root.child 'authz' .push()

z.set req: \user, uri: \http://lqfb-test.g0v.tw/g0v


console.log \done z.name!

<- z.on \value
console.log it.val!
