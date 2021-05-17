#!/usr/bin/env bash

set -e -o pipefail

enum() {
  # shellcheck disable=SC2046
  services=$(docker service inspect $(docker service ls -qf label=menu.item.link))
  export services

  # shellcheck disable=SC2046
  images=$(docker image inspect $(printenv services | jq -r '.[] | .Spec.TaskTemplate.ContainerSpec.Image'))
  export images

  printenv services | jq -r --argjson image_map "$(printenv images | jq '[ .[] | { (.Id): .RepoTags[0] } ] | add')" '
      [
        .[] | {
          index: .Spec.Labels."menu.item.index" | tonumber,
          link: .Spec.Labels."menu.item.link",
          caption: .Spec.Labels."menu.item.caption",
          image: ( $image_map[.Spec.TaskTemplate.ContainerSpec.Image] // .Spec.TaskTemplate.ContainerSpec.Image ),
          replicas: ( .Spec.Mode.Replicated.Replicas // "global" ),
          created: .CreatedAt,
          updated: .UpdatedAt,
        }
      ] | sort_by(.index)
    '
}

html ()
{
  cat << EOF
    <!doctype html>
    <html>
      <head>
        <title>Docker Service Index</title>
        <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.0.0/dist/css/bootstrap.min.css" rel="stylesheet">
      </head>
      <body>
        <div class="container">
          <nav class="navbar navbar-light bg-light">
            <div class="container-fluid">
              <span class="navbar-brand mb-0 h1">Docker Service Index</span>
            </div>
          </nav>
          <table class="table">
            <thead>
              <tr>
                <th scope="col">#</th>
                <th scope="col">Caption</th>
                <th scope="col">Link</th>
                <th scope="col">Image</th>
                <th scope="col">Replicas</th>
                <th scope="col">Created / Updated</th>
              </tr>
            </thead>
            <tbody>
              <script>
              const list = $(enum);
              document.write(
                list
                  .map(({ index, link, caption, image, replicas, created, updated }) => [
                    '<tr>',
                    '<th scope="row">' + index + '</th>',
                    '<td>' + caption + '</td>',
                    '<td><a href="' + link + '">' + link + '</a></td>',
                    '<td>' + image + '</td>',
                    '<td>' + replicas + '</td>',
                    '<td>' + new Date(updated || created).toLocaleString() + '</td>',
                    '</tr>',
                  ].join(''))
                  .join('')
              );
              </script>
            </tbody>
          </table>
        </div>
      </body>
    </html>
EOF
}

(
  ( echo start ; docker events ) | while read; do
    html > /usr/share/nginx/html/index.html
  done
) &

nginx -g "daemon off;"
