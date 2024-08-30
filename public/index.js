import React, { useState, useEffect, useRef } from "react";
import { createConsumer } from "@rails/actioncable";
import {
  useQuery,
  QueryClient,
  QueryClientProvider,
} from "@tanstack/react-query";
import { marked } from "marked";
import {
  List,
  ListItemButton,
  ListItemAvatar,
  Avatar,
  ListItemText,
  Icon,
  Tooltip,
  TextField,
  Button,
} from "@mui/material";
import { FixedSizeList } from "react-window";
import AutoSizer from "react-virtualized-auto-sizer";

const queryClient = new QueryClient();
const consumer = createConsumer();

function MeetingItem(props) {
  const { currentMeetingId } = props;
  const { isPending, error, data } = useQuery({
    queryKey: ["meetings", currentMeetingId],
    queryFn: () =>
      fetch("/meetings/" + currentMeetingId).then((res) => res.json()),
  });

  if (isPending) return "Loading...";
  if (error) return "An error has occurred: " + error.message;

  const { aiSummary, aiActionItems, entry, date, unit, id } = data;
  return (
    <div
      className="prose"
      dangerouslySetInnerHTML={{
        __html: marked.parse(aiSummary + `\n\n---\n\n` + aiActionItems),
      }}
    ></div>
  );
}

function MeetingList({ currentMeetingId, setCurrentMeetingId }) {
  const { isPending, error, data } = useQuery({
    queryKey: ["meetings"],
    queryFn: () => fetch("/meetings").then((res) => res.json()),
  });

  if (isPending) return "Loading...";
  if (error) return "An error has occurred: " + error.message;

  const renderRow = ({ index, data, style }) => {
    const meeting = data[index];
    const { id, date, unit, topic } = meeting;

    return (
      <Tooltip
        title={topic}
        placement="right-end"
        arrow
        slotProps={{
          popper: {
            modifiers: [
              {
                name: "offset",
                options: {
                  offset: [0, 16],
                },
              },
            ],
          },
        }}
      >
        <ListItemButton
          style={style}
          component="div"
          disablePadding
          selected={currentMeetingId == meeting.id}
          onClick={() => setCurrentMeetingId(id)}
        >
          <ListItemText primary={`${unit}-${id}`} secondary={date} />
        </ListItemButton>
      </Tooltip>
    );
  };

  return (
    <AutoSizer>
      {({ height, width }) => (
        <FixedSizeList
          height={height}
          width={width}
          itemCount={data.length}
          itemSize={64}
          itemData={data}
          overscanCount={5}
        >
          {renderRow}
        </FixedSizeList>
      )}
    </AutoSizer>
  );
}

function Chat(props) {
  const { currentMeetingId, subscription, messages, setMessages } = props;
  const [value, setValue] = useState("");
  const inputRef = useRef(null);

  useEffect(() => {
    setValue("");
    setMessages([]);
    inputRef.current.focus();
  }, [currentMeetingId]);

  const onSubmit = async (e) => {
    e.preventDefault();
    setMessages([...messages, { role: "user", content: value }]);
    subscription.send({
      action: "chat_message",
      message: value,
      meeting_id: currentMeetingId,
    });
    setValue("");
  };

  function Messages(props) {
    const { messages } = props;

    return (
      <div className="w-full">
        {messages.map((message, index) => (
          <div className="flex flex-col w-full leading-1.5 p-4 border-gray-200 bg-gray-100 rounded-e-xl rounded-es-xl dark:bg-gray-700 my-2">
            <div className="flex items-center space-x-2 rtl:space-x-reverse">
              <span className="text-sm font-semibold text-gray-900 dark:text-white">
                {message.role === "user" ? "You" : "Assistant"}
              </span>
            </div>
            <span
              key={index}
              dangerouslySetInnerHTML={{
                __html: marked.parse(message.content),
              }}
            ></span>
          </div>
        ))}
      </div>
    );
  }

  return (
    <form onSubmit={onSubmit}>
      <div className="flex flex-col h-full">
        <div className="flex">
          <Messages messages={messages} />
        </div>
        <div className="flex w-3/5 items-center">
          <TextField
            autoFocus
            size="small"
            fullWidth
            value={value}
            onChange={(e) => setValue(e.target.value)}
            ref={inputRef}
          />
          <Button>Send</Button>
        </div>
      </div>
    </form>
  );
}

function App() {
  const [currentMeetingId, setCurrentMeetingId] = useState(461);
  const [subscription, setSubscription] = useState(null);
  const [messages, setMessages] = useState([]);

  useEffect(() => {
    const sub = consumer.subscriptions.create(
      { channel: "MessagesChannel", room: `meeting` },
      {
        received: (recv) => {
          setMessages((messages) => [
            ...messages,
            { role: "assistant", content: recv },
          ]);
        },
      }
    );
    setSubscription(sub);
    return () => sub.unsubscribe();
  }, []);

  return (
    <QueryClientProvider client={queryClient}>
      <section className="w-screen h-screen m-0 p-0 ">
        <div className="flex h-full">
          <div className="w-80 overflow-y-auto bg-gray-100">
            <MeetingList
              currentMeetingId={currentMeetingId}
              setCurrentMeetingId={setCurrentMeetingId}
            />
          </div>
          <div className="flex-1">
            <div className="bg-white p-4 overflow-y-auto h-3/5 border-b-2">
              <MeetingItem currentMeetingId={currentMeetingId} />
            </div>
            <div className="bg-white p-4 overflow-y-auto h-2/5">
              <Chat
                currentMeetingId={currentMeetingId}
                subscription={subscription}
                messages={messages}
                setMessages={setMessages}
              />
            </div>
          </div>
        </div>
      </section>
    </QueryClientProvider>
  );
}

// Mount and bind the React app to the DOM
import { createRoot } from "react-dom";
const domNode = document.getElementById("root");
const root = createRoot(domNode);
root.render(<App />);
