import {request, createServer} from 'http';
import {readFileSync} from 'fs';

const PORT = 80;
const DOCKER_SOCKET = '/var/run/docker.sock';

const query = async (path, params) => new Promise((resolve, reject) => {
    const url = new URL(path, 'http://localhost');
    Object.entries(params ?? {})
        .filter(([, value]) => value ?? false)
        .forEach(([name, value]) => url.searchParams.append(name, (value && typeof value === 'object' ? JSON.stringify : String)(value)));

    const req = request(url, {socketPath: DOCKER_SOCKET});
    req.on('error', reject);
    req.on('response', async res => {
        try {
            res.setEncoding('utf8');
            res.on('error', reject);
            const chunks = [];
            for await (let chunk of res) {
                chunks.push(chunk);
            }
            resolve(JSON.parse(chunks.join('')));
        } catch (error) {
            reject(error);
        }
    });
    req.end();
});

const listImages = async () => query('/images/json');

const listServices = async (filters) => query('/services', {filters});

const getItems = async () => {
    const services = await listServices({label: ['menu.item.link']});
    const images = await listImages();
    return services
        .map(({CreatedAt, UpdatedAt, Spec: {Mode, Labels, TaskTemplate: {ContainerSpec: {Image}}}}) => ({
            index: parseInt(Labels['menu.item.index']),
            link: Labels['menu.item.link'],
            caption: Labels['menu.item.caption'],
            image: images.find(({Id}) => Id === Image)?.RepoTags?.[0] ?? Image,
            replicas: Mode?.Replicated?.Replicas ?? 'global',
            created: CreatedAt,
            updated: UpdatedAt,
        }))
        .sort(({index: a}, {index: b}) => a < b);
};

console.log('Checking Docker version...');
try {
    console.dir(await query('/version'), {depth: null});
} catch (error) {
    console.log('Docker connection failed');
    console.dir(error, {depth: null});
    process.exit(1);
}

console.log('Loading template...');
let template;
try {
    template = (await readFileSync('./template.html', {encoding: 'utf8'}));
} catch (error) {
    console.log('Failed loading template:', error);
    process.exit(1);
}

const server = createServer(async (req, res) => {
    console.log(`${new Date().toISOString()} HTTP${req.httpVersion} ${req.method} ${req.url} ${req.connection.remoteAddress ?? '-'} ${req.headers['user-agent'] ?? '-'}`);
    let response;
    try {
        const items = await getItems();
        response = template.replace('\'{PLACEHOLDER}\'', JSON.stringify(items, null, 2));
    } catch (error) {
        console.dir(error, {depth: null});
        res.writeHead(500);
        res.end('500 Internal server error', 'utf8');
        return;
    }
    res.writeHead(200, {'Content-Type': 'text/html; charset=utf-8'});
    res.end(response, 'utf8');
});

process.once('SIGINT', () => {
    console.log('SIGINT received, shutting down server...');
    server.close();
});

server.listen(PORT, () => {
    console.log(`Server started on port ${PORT}...`);
});
