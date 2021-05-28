FROM astefanutti/scratch-node:16
COPY template.html index.mjs ./
EXPOSE 80
USER 0
CMD ["/index.mjs"]
