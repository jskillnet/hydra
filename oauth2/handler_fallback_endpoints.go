/*
 * Copyright © 2015-2018 Aeneas Rekkas <aeneas+oss@aeneas.io>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * @author		Aeneas Rekkas <aeneas+oss@aeneas.io>
 * @copyright 	2015-2018 Aeneas Rekkas <aeneas+oss@aeneas.io>
 * @license 	Apache-2.0
 */

package oauth2

import (
	"html/template"
	"net/http"

	"github.com/julienschmidt/httprouter"
)

func (h *Handler) DefaultConsentHandler(w http.ResponseWriter, r *http.Request, _ httprouter.Params) {
	h.r.Logger().Warnln("It looks like no consent/login URL was set. All OAuth2 flows except client credentials will fail.")
	h.r.Logger().Warnln("A client requested the default login & consent URL, environment variable OAUTH2_CONSENT_URL or OAUTH2_LOGIN_URL or both are probably not set.")

	t, err := template.New("consent").Parse(`
<html>
<head>
	<title>Misconfigured consent/login URL</title>
</head>
<body>
<p>
	It looks like you forgot to set the consent/login provider url, which can be set using the <code>OAUTH2_CONSENT_URL</code> and <code>OAUTH2_LOGIN_URL</code>
	environment variable.
</p>
<p>
	If you are an administrator, please read <a href="https://www.ory.sh/docs">
	the guide</a> to understand what you need to do. If you are a user, please contact the administrator.
</p>
</body>
</html>
`)
	if err != nil {
		h.r.Writer().WriteError(w, r, err)
		return
	}

	if err := t.Execute(w, nil); err != nil {
		h.r.Writer().WriteError(w, r, err)
		return
	}
}

func (h *Handler) DefaultErrorHandler(w http.ResponseWriter, r *http.Request, _ httprouter.Params) {
	h.r.Logger().Warnln("A client requested the default error URL, environment variable OAUTH2_ERROR_URL is probably not set.")

	t, err := template.New("consent").Parse(`
<html>
<head>
	<title>An OAuth 2.0 Error Occurred</title>
</head>
<body>
<h1>
	The OAuth2 request resulted in an error.
</h1>
<ul>
	<li>Error: {{ .Name }}</li>
	<li>Description: {{ .Description }}</li>
	<li>Hint: {{ .Hint }}</li>
	<li>Debug: {{ .Debug }}</li>
</ul>
<p>
	You are seeing this default error page because the administrator has not set a dedicated error URL (environment variable <code>OAUTH2_ERROR_URL</code> is not set). 
	If you are an administrator, please read <a href="https://www.ory.sh/docs">the guide</a> to understand what you
	need to do. If you are a user, please contact the administrator.
</p>
</body>
</html>
`)
	if err != nil {
		h.r.Writer().WriteError(w, r, err)
		return
	}

	if err := t.Execute(w, struct {
		Name        string
		Description string
		Hint        string
		Debug       string
	}{
		Name:        r.URL.Query().Get("error"),
		Description: r.URL.Query().Get("error_description"),
		Hint:        r.URL.Query().Get("error_hint"),
		Debug:       r.URL.Query().Get("error_debug"),
	}); err != nil {
		h.r.Writer().WriteError(w, r, err)
		return
	}
}

func (h *Handler) DefaultLogoutHandler(w http.ResponseWriter, r *http.Request, _ httprouter.Params) {
	h.r.Logger().Warnln("A client requested the default logout URL, environment variable OAUTH2_LOGOUT_REDIRECT_URL is probably not set.")
	t, err := template.New("consent").Parse(`
<html>
<head>
	<title>You logged out successfully</title>
</head>
<body>
<h1>
	You logged out successfully!
</h1>
<p>
	You are seeing this default page because the administrator did not specify a redirect URL (environment variable <code>OAUTH2_LOGOUT_REDIRECT_URL</code> is not set). 
	If you are an administrator, please read <a href="https://www.ory.sh/docs">the guide</a> to understand what you
	need to do. If you are a user, please contact the administrator.
</p>
</body>
</html>
`)
	if err != nil {
		h.r.Writer().WriteError(w, r, err)
		return
	}

	if err := t.Execute(w, nil); err != nil {
		h.r.Writer().WriteError(w, r, err)
		return
	}
}
