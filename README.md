# Description

Flowdometer automatically tracks your process in Salesforce. It can monitor any Object, and changes to any Field, usually something named Status or Stage.

# Driveway

Driveway is an exceptional Salesforce documentation tool. The guides below become interactive in your own org if you download the free Chrome Extension here: https://chrome.google.com/webstore/detail/driveway/cdekmndccoppabcjlfflndphloafcgpf

# Flowdometer Installation

First, get Flowdometer installed into your org here: https://on.driveway.app/guides/zEVBqzE

# Tracking

Next, set up listeners to track changes to fields over time here: https://on.driveway.app/guides/bLekwqW

# Goals / SLAs

Lastly\* set up your goals here: https://on.driveway.app/guides/0LYOe0W

_\*Even if missing targets is not meant to punish employees, best practices are to at least set conservative estimates for a process, to make sure you aren't bottlenecking in ways you haven't anticipated. Having goals also makes the Flowdometer Dashboards a lot more interesting._

# Extending Flowdometer

Flowdometer is an open-source project that is designed to be built on top of. The Flow and Step objects can be added to with whatever fields are necessary for your use case.

**Flowdometer data on my tracked record**

For example, you might build an automation to have your tracked object point at the Flow Tracker record that is tracking it. This would allow you to then pull in the data from the Flow record, and Most Recent Step record, including goal attainment progress bars, and put them directly on the tracked object. Imagine sorting all your opportunities by Next Breach At.

**Business Hours**

Another example, Flowdometer doesn’t support business hours out of the box, but we’ve included another open source project from Unofficial SF that will allow you to calculate these times in Flow Builder. In Flow Builder, check out the flow template we made called "Flowdometer - Autocalculate Business Hours". In there, you'll see how you can use an Action (created by Professor Flow - thank you!) that will allow you to create whatever rules you have for different business hours in your company, and calculate them with this action.
